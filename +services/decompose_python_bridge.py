#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
EMG Online Decomposition Bridge
Called from MATLAB DecompositionService via system() to perform
ICA-based online EMG decomposition using pre-trained templates.

Usage:
    python decompose_python_bridge.py <emg_flexor_path> <emg_extensor_path> <template_dir> <output_dir>

Output:
    JSON result string printed to stdout, plus CSV spike train files in output_dir.
"""

import sys
import os
import json
import numpy as np
import pandas as pd
import joblib
import scipy.io as sio
import warnings
import re
import glob
os.environ['HDF5_DISABLE_VERSION_CHECK'] = '1'
warnings.filterwarnings('ignore')


def load_mat_emg(filepath):
    """Load EMG variable from .mat file (v7 or v7.3), return (samples, channels)."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")

    data = None
    try:
        data = sio.loadmat(filepath)
        for key in data:
            if not key.startswith('__') and isinstance(data[key], np.ndarray) and data[key].ndim == 2:
                data = data[key]
                break
    except NotImplementedError:
        pass

    if data is None or isinstance(data, dict):
        import h5py
        with h5py.File(filepath, 'r') as f:
            for key in f.keys():
                data = np.array(f[key])
                break

    if data is None:
        raise RuntimeError(f"No numeric matrix found in {filepath}")

    if data.ndim != 2:
        raise RuntimeError(f"Expected 2D matrix in {filepath}, got shape {data.shape}")

    n_rows, n_cols = data.shape
    if n_rows <= 128 and n_cols > n_rows:
        data = data.T

    return data.astype(np.float64)


def find_template_files(template_dir):
    """Find ICA model, center, and valid_index files for T18 template.

    Returns dict with keys: ica_dev0, ica_dev1, center_dev0, center_dev1,
    index_dev0, index_dev1, subject_id.
    """
    pattern_ica0 = os.path.join(template_dir, '*_ica_model_T*_dev0.pkl')
    matches = glob.glob(pattern_ica0)
    if not matches:
        raise FileNotFoundError(
            f"No ICA model files found in {template_dir}. "
            f"Expected pattern: *_ica_model_T*_dev0.pkl"
        )

    ica_file = os.path.basename(matches[0])
    m = re.match(r'(.+)_ica_model_T(\d+)_dev0\.pkl', ica_file)
    if not m:
        raise RuntimeError(f"Cannot parse template filename: {ica_file}")
    subject_id = m.group(1)
    motion_id = m.group(2)

    templates = {'subject_id': subject_id, 'motion_id': int(motion_id)}

    required = [
        ('ica_dev0', f'{subject_id}_ica_model_T{motion_id}_dev0.pkl'),
        ('ica_dev1', f'{subject_id}_ica_model_T{motion_id}_dev1.pkl'),
        ('center_dev0', f'{subject_id}_center_T{motion_id}_dev0.csv'),
        ('center_dev1', f'{subject_id}_center_T{motion_id}_dev1.csv'),
        ('index_dev0', f'{subject_id}_valid_index_T{motion_id}_dev0.csv'),
        ('index_dev1', f'{subject_id}_valid_index_T{motion_id}_dev1.csv'),
    ]

    for key, fname in required:
        fpath = os.path.join(template_dir, fname)
        if not os.path.exists(fpath):
            raise FileNotFoundError(f"Missing template file: {fpath}")
        templates[key] = fpath

    return templates


def load_templates(template_files):
    """Load all template data into memory."""
    templates = {}
    templates['ica_dev0'] = joblib.load(template_files['ica_dev0'])
    templates['ica_dev1'] = joblib.load(template_files['ica_dev1'])
    templates['center_dev0'] = pd.read_csv(template_files['center_dev0'], header=None).to_numpy()
    templates['center_dev1'] = pd.read_csv(template_files['center_dev1'], header=None).to_numpy()
    templates['index_dev0'] = pd.read_csv(template_files['index_dev0'], header=None).to_numpy()
    templates['index_dev1'] = pd.read_csv(template_files['index_dev1'], header=None).to_numpy()
    templates['subject_id'] = template_files['subject_id']
    return templates


def extend_signal(data, num_extend=9):
    """Extend EMG signal by adding delayed copies of each channel.

    Args:
        data: (samples, channels) numpy array
        num_extend: number of delayed copies per channel

    Returns:
        extended: (samples - num_extend, channels * (num_extend + 1))
    """
    df = pd.DataFrame(data)
    parts = [df] + [df.shift(-x) for x in range(num_extend)]
    extended = pd.concat(parts, axis=1).dropna()
    extended = extended - extended.mean(axis=0)
    return extended.to_numpy()


def classify_spikes(emg_mu_peak, saved_centers):
    """Classify detected peaks into spikes using saved cluster centers.

    Args:
        emg_mu_peak: (samples, n_mu) - peak values (0 for non-peak positions)
        saved_centers: (2, n_mu) - [center_small, center_large] per MU

    Returns:
        spike_train: (samples, n_mu) binary matrix
    """
    n_mu = emg_mu_peak.shape[1]
    spike_train = np.zeros_like(emg_mu_peak)

    if saved_centers.ndim == 3:
        saved_centers = saved_centers.squeeze(axis=-1)

    for i in range(n_mu):
        spikes_idx = np.nonzero(emg_mu_peak[:, i])[0]
        spikes_vals = emg_mu_peak[spikes_idx, i]
        if len(spikes_vals) == 0:
            continue

        center_small = saved_centers[0, i]
        center_large = saved_centers[1, i]
        threshold = (center_small + center_large) / 2.0

        true_spike_mask = spikes_vals > threshold
        real_spike_idx = spikes_idx[true_spike_mask]
        spike_train[real_spike_idx, i] = 1

    return spike_train


def decompose_one_side(emg, ica_model, center, valid_index):
    """Run online decomposition for one side (flexor or extensor).

    Args:
        emg: (samples, channels) raw EMG
        ica_model: trained FastICA model
        center: (2, n_valid_mu) cluster centers from training
        valid_index: (n_valid_mu,) indices of valid MUs

    Returns:
        spike_train: (samples, n_valid_mu) binary spike train matrix
    """
    num_extend = 9
    extended = extend_signal(emg, num_extend)

    sources = ica_model.transform(extended)
    sources_sq = sources * np.abs(sources)

    # Filter to valid MUs only
    idx = valid_index.flatten().astype(int)
    sources_sq_valid = sources_sq[:, idx]

    # Peak detection
    pre_diff = pd.DataFrame(sources_sq_valid).diff(-1) > 0
    post_diff = pd.DataFrame(sources_sq_valid).diff(1) > 0
    peaks = sources_sq_valid * pre_diff.values * post_diff.values

    # Classify using saved centers
    spike_train = classify_spikes(peaks, center)

    return spike_train


def run_decomposition(emg_flexor_path, emg_extensor_path, template_dir, output_dir):
    """Main decomposition routine.

    Returns:
        dict with keys: status, n_flexor_mu, n_extensor_mu, n_samples,
        spike_train_flexor_path, spike_train_extensor_path, subject_id, message
    """
    print(f"[Python Bridge] Loading EMG data...", flush=True)

    emg_f = load_mat_emg(emg_flexor_path)
    emg_e = load_mat_emg(emg_extensor_path)
    print(f"[Python Bridge] Flexor: {emg_f.shape}, Extensor: {emg_e.shape}", flush=True)

    print(f"[Python Bridge] Finding templates in {template_dir}...", flush=True)
    template_files = find_template_files(template_dir)
    print(f"[Python Bridge] Subject: {template_files['subject_id']}, "
          f"Template motion: T{template_files['motion_id']}", flush=True)

    print(f"[Python Bridge] Loading templates...", flush=True)
    templates = load_templates(template_files)

    print(f"[Python Bridge] Running flexor decomposition...", flush=True)
    st_flexor = decompose_one_side(
        emg_f,
        templates['ica_dev0'],
        templates['center_dev0'],
        templates['index_dev0']
    )
    print(f"[Python Bridge] Flexor done: {st_flexor.shape[1]} MUs, {st_flexor.shape[0]} samples",
          flush=True)

    print(f"[Python Bridge] Running extensor decomposition...", flush=True)
    st_extensor = decompose_one_side(
        emg_e,
        templates['ica_dev1'],
        templates['center_dev1'],
        templates['index_dev1']
    )
    print(f"[Python Bridge] Extensor done: {st_extensor.shape[1]} MUs, {st_extensor.shape[0]} samples",
          flush=True)

    os.makedirs(output_dir, exist_ok=True)

    flexor_basename = os.path.splitext(os.path.basename(emg_flexor_path))[0]
    extensor_basename = os.path.splitext(os.path.basename(emg_extensor_path))[0]

    # Save as (n_mu, n_samples) for MATLAB compatibility
    st_flexor_out = st_flexor.T
    st_extensor_out = st_extensor.T

    flexor_csv = os.path.join(output_dir, f'{flexor_basename}_spike_train.csv')
    extensor_csv = os.path.join(output_dir, f'{extensor_basename}_spike_train.csv')

    np.savetxt(flexor_csv, st_flexor_out, delimiter=',', fmt='%d')
    np.savetxt(extensor_csv, st_extensor_out, delimiter=',', fmt='%d')

    print(f"[Python Bridge] Results saved to {output_dir}", flush=True)

    return {
        'status': 'success',
        'subject_id': templates['subject_id'],
        # 'template_motion': templates['motion_id'],
        'n_flexor_mu': st_flexor_out.shape[0],
        'n_extensor_mu': st_extensor_out.shape[0],
        'n_samples_flexor': st_flexor_out.shape[1],
        'n_samples_extensor': st_extensor_out.shape[1],
        'spike_train_flexor_path': flexor_csv,
        'spike_train_extensor_path': extensor_csv,
        'message': (f"Decomposition complete: {st_flexor_out.shape[0]} flexor MUs + "
                    f"{st_extensor_out.shape[0]} extensor MUs, "
                    f"{st_flexor_out.shape[1]} samples")
    }


def main():
    if len(sys.argv) < 4:
        print(json.dumps({
            'status': 'error',
            'message': 'Usage: python decompose_python_bridge.py <emg_flexor_path> <emg_extensor_path> <template_dir> [output_dir]'
        }))
        sys.exit(1)

    emg_flexor_path = sys.argv[1]
    emg_extensor_path = sys.argv[2]
    template_dir = sys.argv[3]
    output_dir = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(emg_flexor_path)

    try:
        result = run_decomposition(emg_flexor_path, emg_extensor_path, template_dir, output_dir)
        print(json.dumps(result))
    except Exception as e:
        import traceback
        print(json.dumps({
            'status': 'error',
            'message': str(e),
            'traceback': traceback.format_exc()
        }))
        sys.exit(1)


if __name__ == '__main__':
    main()
