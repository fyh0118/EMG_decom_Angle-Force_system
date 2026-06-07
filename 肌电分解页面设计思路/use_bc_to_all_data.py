# -*- coding: utf-8 -*-
"""
Created on Mon Feb  9 17:52:43 2026

@author: ying
"""
import h5py

from utils import plotspikes
import numpy as np
import pandas as pd
from sklearn.decomposition import FastICA
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from pathlib import Path
import pickle
import json
import matplotlib.pyplot as plt
import matplotlib
import time
import joblib

# import tensorflow as tf
# tf.debugging.set_log_device_placement(True)
# from tensorflow import keras

import os  # Move back to the main folder, Make sure to run this cell only at the start

from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import scipy.io as sio
import re

if __name__ == "__main__":

    func = 'exp'  # ‘logcosh’, ‘exp’, ‘cube’
    alg = 'parallel'  # ‘parallel’, ‘deflation’
    # thre_sil = 0.9
    num_of_extend = 9

    num_of_mu = 64

    list_mo = [18]
    read_emg_path = r'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\EMG_Data\EMG_CSV\EMG_cleanPRO'
    read_file_path = r'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mixEMG\正确版python单拼\SIL0.85\save_bc'  # save_bc所在文件夹
    save_st_path = r'F:\正确版python单拼_st0.85'   # 在线分解结果所在文件夹
    os.makedirs(save_st_path, exist_ok=True)
    all_ica = {}
    all_center = {}
    all_index = {}

    for num_of_motion in list_mo:
        # all_ica[f'zwb_ica_f_{num_of_motion}'] = joblib.load(
        #     os.path.join(read_file_path, f'zwb_ica_model_f_{num_of_motion}.pkl'))
        # all_ica[f'zwb_ica_e_{num_of_motion}'] = joblib.load(
        #     os.path.join(read_file_path, f'zwb_ica_model_e_{num_of_motion}.pkl'))
        all_ica[f'S02_ica_T{num_of_motion}_dev0'] = joblib.load(
            os.path.join(read_file_path, f'S02_ica_model_T{num_of_motion}_dev0.pkl'))
        all_ica[f'S02_ica_T{num_of_motion}_dev1'] = joblib.load(
            os.path.join(read_file_path, f'S02_ica_model_T{num_of_motion}_dev1.pkl'))

        # all_center[f'zwb_c_f_{num_of_motion}'] = pd.read_csv(
        #     os.path.join(read_file_path, f'zwb_center_f_{num_of_motion}.csv'), header=None).to_numpy()
        # all_center[f'zwb_c_e_{num_of_motion}'] = pd.read_csv(
        #     os.path.join(read_file_path, f'zwb_center_e_{num_of_motion}.csv'), header=None).to_numpy()
        all_center[f'S02_c_T{num_of_motion}_dev0'] = pd.read_csv(
            os.path.join(read_file_path, f'S02_center_T{num_of_motion}_dev0.csv'), header=None).to_numpy()
        all_center[f'S02_c_T{num_of_motion}_dev1'] = pd.read_csv(
            os.path.join(read_file_path, f'S02_center_T{num_of_motion}_dev1.csv'), header=None).to_numpy()

        # all_index[f'zwb_d_f_{num_of_motion}'] = pd.read_csv(
        #     os.path.join(read_file_path, f'zwb_valid_index_f_{num_of_motion}.csv'), header=None).to_numpy()
        # all_index[f'zwb_d_e_{num_of_motion}'] = pd.read_csv(
        #     os.path.join(read_file_path, f'zwb_valid_index_e_{num_of_motion}.csv'), header=None).to_numpy()
        all_index[f'S02_d_T{num_of_motion}_dev0'] = pd.read_csv(
            os.path.join(read_file_path, f'S02_valid_index_T{num_of_motion}_dev0.csv'), header=None).to_numpy()
        all_index[f'S02_d_T{num_of_motion}_dev1'] = pd.read_csv(
            os.path.join(read_file_path, f'S02_valid_index_T{num_of_motion}_dev1.csv'), header=None).to_numpy()

    st1_all = []
    st2_all = []
    # 获取所有mat文件
    mat_folder = r'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\EMG_Data\EMG_CSV\EMG_cleanPRO'
    all_files = [f for f in os.listdir(mat_folder) if f.endswith('.mat')]

    # === 修改：按 (F, T) 分组 ===
    pattern = r'S02_G01_F(\d+)_T(\d+)_dev(\d)\.mat'

    file_dict = {}

    for f in all_files:
        match = re.match(pattern, f)
        if match:
            F, T, dev = match.groups()
            key = f'F{F}_T{T}'
            if key not in file_dict:
                file_dict[key] = {}
            file_dict[key][dev] = f

    # === 修改：遍历每一个 trial（必须同时有 dev0 和 dev1） ===
    for key in file_dict:
        if '0' not in file_dict[key] or '1' not in file_dict[key]:
            continue  # 跳过不完整的

        file_dev0 = file_dict[key]['0']
        file_dev1 = file_dict[key]['1']

        print(f'Processing {key}')

        # === 修改：读取 mat 并取 EMG + 转置 ===
        # data_f = sio.loadmat(os.path.join(mat_folder, file_dev0))['EMG'].T
        # data_e = sio.loadmat(os.path.join(mat_folder, file_dev1))['EMG'].T
        with h5py.File(os.path.join(mat_folder, file_dev0), 'r') as f:
            data_f = np.array(f['EMG'])
        with h5py.File(os.path.join(mat_folder, file_dev1), 'r') as f:
            data_e = np.array(f['EMG'])

        # 数据拓展
        df_emg_raw1 = pd.DataFrame(data_f)
        emg_extended1 = pd.concat([df_emg_raw1] + [df_emg_raw1.shift(-x) for x in range(num_of_extend)],
                                  axis=1).dropna()
        emg_preprocessed1 = emg_extended1 - np.mean(emg_extended1, axis=0)

        df_emg_raw2 = pd.DataFrame(data_e)
        emg_extended2 = pd.concat([df_emg_raw2] + [df_emg_raw2.shift(-x) for x in range(num_of_extend)],
                                  axis=1).dropna()
        emg_preprocessed2 = emg_extended2 - np.mean(emg_extended2, axis=0)

        # ica分解
        cashe_name = 'all'

        st1 = []
        st2 = []

        for num_of_motion2 in list_mo:
            print(f'start al ICA mo {num_of_motion2}')

            emg_FastICA1 = all_ica[f'S02_ica_T{num_of_motion2}_dev0']
            emg_FastICA2 = all_ica[f'S02_ica_T{num_of_motion2}_dev1']

            emg_mu1 = emg_FastICA1.transform(emg_preprocessed1)
            emg_mu_square1 = emg_mu1 * np.abs(emg_mu1)

            emg_mu2 = emg_FastICA2.transform(emg_preprocessed2)
            emg_mu_square2 = emg_mu2 * np.abs(emg_mu2)

            valid_index_mu1 = all_index[f'S02_d_T{num_of_motion2}_dev0']
            emg_mu_squared1 = emg_mu_square1[:, valid_index_mu1.flatten().astype(int)]

            valid_index_mu2 = all_index[f'S02_d_T{num_of_motion2}_dev1']
            emg_mu_squared2 = emg_mu_square2[:, valid_index_mu2.flatten().astype(int)]

            # kmeans
            print('start all kmeans')
            # 1. 预处理：变成只有尖端值
            pre_diff1 = pd.DataFrame(emg_mu_squared1).diff(-1) > 0
            post_diff1 = pd.DataFrame(emg_mu_squared1).diff(1) > 0
            emg_mu_peak1 = emg_mu_squared1 * pre_diff1.values * post_diff1.values

            pre_diff2 = pd.DataFrame(emg_mu_squared2).diff(-1) > 0
            post_diff2 = pd.DataFrame(emg_mu_squared2).diff(1) > 0
            emg_mu_peak2 = emg_mu_squared2 * pre_diff2.values * post_diff2.values

            # 2. 初始化容器
            saved_centers1 = all_center[f'S02_c_T{num_of_motion2}_dev0']
            spike_trains1 = np.zeros_like(emg_mu_squared1)

            saved_centers2 = all_center[f'S02_c_T{num_of_motion2}_dev1']
            spike_trains2 = np.zeros_like(emg_mu_squared2)

            num_of_mu1 = emg_mu_squared1.shape[1]
            num_of_mu2 = emg_mu_squared2.shape[1]

            for i in range(num_of_mu1):
                # --- A. 提取当前通道的波峰 ---
                spikes_indices = np.nonzero(emg_mu_peak1[:, i])[0]
                spikes_values = emg_mu_peak1[spikes_indices, i]

                if len(spikes_values) == 0:
                    continue

                # --- B. 获取该通道保存好的聚类中心 ---
                # 假设 saved_centers 的形状是 (2, num_of_mu, 1)
                # center_small 通常代表噪声/背景 (Label 0)
                # center_large 通常代表 Spike (Label 1)
                center_small = saved_centers1[0, i]
                center_large = saved_centers1[1, i]

                # --- C. 计算决策阈值 ---
                # 在 1D KMeans 中，决策边界就是两个中心的中点
                threshold = (center_small + center_large) / 2

                # --- D. 分类 (生成 0 和 1) ---
                # 如果波峰值 > 阈值，则认为离 center_large 更近，标记为 1
                # 如果波峰值 < 阈值，则认为离 center_small 更近，标记为 0
                # 因为 spike_trains1 初始化就是 0，我们只需要把判定为 1 的位置填进去即可

                # 找出所有大于阈值的波峰的索引（在 spikes_indices 中的位置）
                true_spike_mask = spikes_values > threshold

                # 获取这些真正的 Spike 在原始时间序列中的索引
                real_spike_indices = spikes_indices[true_spike_mask]

                # --- E. 赋值 ---
                spike_trains1[real_spike_indices, i] = 1

            for i in range(num_of_mu2):
                # --- A. 提取当前通道的波峰 ---
                spikes_indices = np.nonzero(emg_mu_peak2[:, i])[0]
                spikes_values = emg_mu_peak2[spikes_indices, i]

                if len(spikes_values) == 0:
                    continue

                # --- B. 获取该通道保存好的聚类中心 ---
                # 假设 saved_centers 的形状是 (2, num_of_mu, 1)
                # center_small 通常代表噪声/背景 (Label 0)
                # center_large 通常代表 Spike (Label 1)
                center_small = saved_centers2[0, i]
                center_large = saved_centers2[1, i]

                # --- C. 计算决策阈值 ---
                # 在 1D KMeans 中，决策边界就是两个中心的中点
                threshold = (center_small + center_large) / 2

                # --- D. 分类 (生成 0 和 1) ---
                # 如果波峰值 > 阈值，则认为离 center_large 更近，标记为 1
                # 如果波峰值 < 阈值，则认为离 center_small 更近，标记为 0
                # 因为 spike_trains1 初始化就是 0，我们只需要把判定为 1 的位置填进去即可

                # 找出所有大于阈值的波峰的索引（在 spikes_indices 中的位置）
                true_spike_mask = spikes_values > threshold

                # 获取这些真正的 Spike 在原始时间序列中的索引
                real_spike_indices = spikes_indices[true_spike_mask]

                # --- E. 赋值 ---
                spike_trains2[real_spike_indices, i] = 1

            st1.append(spike_trains1)
            st2.append(spike_trains2)

        st1_1mo = np.concatenate(st1, axis=1)
        st2_1mo = np.concatenate(st2, axis=1)

        # plotspikes(st1_1mo[:, :], title=f'f_mo{num_of_motion1}')
        # plt.close('all')
        #
        # np.savetxt(os.path.join(save_st_path, f'S02_st_F{}_T{}_dev0.csv'), st1_1mo, delimiter=',')
        # np.savetxt(os.path.join(save_st_path, f'S02_st_F{}_T{}_dev1.csv'), st2_1mo, delimiter=',')
        # === 修改：从 key 解析 F 和 T ===
        F_str, T_str = key.split('_')  # F10, T02

        # === 修改：plot标题更清晰 ===
        # plotspikes(st1_1mo[:, :], title=f'{F_str}_{T_str}_dev0')
        # plt.close('all')

        # === 修改：保存文件名 ===
        np.savetxt(
            os.path.join(save_st_path, f'S02_st_{F_str}_{T_str}_dev0.csv'),
            st1_1mo,
            delimiter=','
        )

        np.savetxt(
            os.path.join(save_st_path, f'S02_st_{F_str}_{T_str}_dev1.csv'),
            st2_1mo,
            delimiter=','
        )
