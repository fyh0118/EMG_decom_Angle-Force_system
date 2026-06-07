# -*- coding: utf-8 -*-
"""
Created on Mon Feb  9 11:37:15 2026

@author: ying
"""

from utils import plotspikes
import numpy as np
import pandas as pd
from sklearn.decomposition import FastICA
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

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

# def main():


if __name__ == "__main__":

    func = 'exp'  # ‘logcosh’, ‘exp’, ‘cube’
    alg = 'parallel'  # ‘parallel’, ‘deflation’
    thre_sil = 0.85  # 默认是0.9
    num_of_extend = 9

    num_of_mu = 64
# 樊雨函的电脑只能跑单个trail的结果
    list_mo = [345]
    read_file_path = r'G:\matlab_projects\CKC_achieve\data\EMG_FYH\G01\G01_mixForce\python分解三拼\data'
    save_file_path = r'G:\matlab_projects\CKC_achieve\data\EMG_FYH\G01\G01_mixForce\python分解三拼'
    # main()
    for num_of_motion in list_mo:
        # --- 构建文件名 ---
        file_name_f = f'EMG_merged_T{num_of_motion}_dev0.csv'
        file_name_e = f'EMG_merged_T{num_of_motion}_dev1.csv'
        # file_name_f = f'zwb_filted_emg_f_{num_of_motion}.csv'
        # file_name_e = f'zwb_filted_emg_e_{num_of_motion}.csv'

        # 使用 os.path.join 拼接路径，比直接字符串相加更安全
        full_path_f = os.path.join(read_file_path, file_name_f)
        full_path_e = os.path.join(read_file_path, file_name_e)

        # --- 读取数据 ---
        # header=None 表示假设 CSV 没有标题行（如果有标题行，请去掉 header=None）
        # .to_numpy() 将 DataFrame 转换为类似 MATLAB 矩阵的 NumPy 数组
        try:
            data_f = pd.read_csv(full_path_f, header=None).to_numpy()
            data_e = pd.read_csv(full_path_e, header=None).to_numpy()

            print(f"成功读取 motion {num_of_motion}")

        except FileNotFoundError:
            print(f"文件未找到: {file_name_f} 或 {file_name_e}")

        total_rows_f = data_f.shape[0]  # 获取 data_f 的总行数
        total_rows_e = data_e.shape[0]  # 获取 data_e 的总行数
        emg_f = data_f[1:total_rows_f + num_of_extend, :]
        emg_e = data_e[1:total_rows_e + num_of_extend, :]

        # 数据拓展
        df_emg_raw1 = pd.DataFrame(emg_f)
        emg_extended1 = pd.concat([df_emg_raw1] + [df_emg_raw1.shift(-x) for x in range(num_of_extend)],
                                  axis=1).dropna()
        emg_preprocessed1 = emg_extended1 - np.mean(emg_extended1, axis=0)

        df_emg_raw2 = pd.DataFrame(emg_e)
        emg_extended2 = pd.concat([df_emg_raw2] + [df_emg_raw2.shift(-x) for x in range(num_of_extend)],
                                  axis=1).dropna()
        emg_preprocessed2 = emg_extended2 - np.mean(emg_extended2, axis=0)

        # ica分解
        cashe_name = 'all'
        print('start ICA')
        emg_FastICA1 = FastICA(n_components=num_of_mu,
                               random_state=42,
                               max_iter=500,
                               tol=1e-4,
                               # whiten=ica_whiten,
                               fun=func,
                               algorithm=alg
                               )
        emg_FastICA2 = FastICA(n_components=num_of_mu,
                               random_state=42,
                               max_iter=500,
                               tol=1e-4,
                               # whiten=ica_whiten,
                               fun=func,
                               algorithm=alg
                               )

        emg_FastICA1.fit(emg_preprocessed1)
        emg_mu1 = emg_FastICA1.transform(emg_preprocessed1)
        emg_mu_squared1 = emg_mu1 * np.abs(emg_mu1)

        emg_FastICA2.fit(emg_preprocessed2)
        emg_mu2 = emg_FastICA2.transform(emg_preprocessed2)
        emg_mu_squared2 = emg_mu2 * np.abs(emg_mu2)

        # --- 保存 ---
        # 这会生成一个二进制文件 'ica_components.npy'
        # file_name_f = f'zwb_ica_model_f_{num_of_motion}.pkl'
        file_name_f = f'S02_ica_model_T{num_of_motion}_dev0.pkl'
        file_name_e = f'S02_ica_model_T{num_of_motion}_dev1.pkl'

        full_path_f = os.path.join(save_file_path, file_name_f)
        full_path_e = os.path.join(save_file_path, file_name_e)

        joblib.dump(emg_FastICA1, full_path_f) # 改了bug，原来是把emg_FastICA2写在了emg_FastICA1
        joblib.dump(emg_FastICA2, full_path_e)
        print("components_ 已保存为 .npy 文件")

        # kmeans
        print('start kmeans')

        # 1. 预处理：变成只有尖端值
        pre_diff1 = pd.DataFrame(emg_mu_squared1).diff(-1) > 0
        post_diff1 = pd.DataFrame(emg_mu_squared1).diff(1) > 0
        emg_mu_peak1 = emg_mu_squared1 * pre_diff1.values * post_diff1.values

        pre_diff2 = pd.DataFrame(emg_mu_squared2).diff(-1) > 0
        post_diff2 = pd.DataFrame(emg_mu_squared2).diff(1) > 0
        emg_mu_peak2 = emg_mu_squared2 * pre_diff2.values * post_diff2.values

        # 2. 初始化容器
        cluster_centers1 = np.zeros((2, num_of_mu, 1))
        spike_trains1 = np.zeros_like(emg_mu_squared1)
        list_sil1 = np.zeros((num_of_mu, 1))

        cluster_centers2 = np.zeros((2, num_of_mu, 1))
        spike_trains2 = np.zeros_like(emg_mu_squared2)
        list_sil2 = np.zeros((num_of_mu, 1))

        for i in range(emg_mu_squared1.shape[1]):
            # 提取波峰数据
            spikes_indices = np.nonzero(emg_mu_peak1[:, i])[0]
            spikes = emg_mu_peak1[spikes_indices, i].reshape((-1, 1))

            # K-Means 聚类
            _kmeans = KMeans(n_clusters=2, max_iter=10000, random_state=None)
            _kmeans.fit(spikes)

            # --- 关键排序步骤 (用于矫正标签) ---
            # idx: [0, 1] 或 [1, 0]，指示从小到大的顺序
            idx = np.argsort(_kmeans.cluster_centers_.sum(axis=1))  # 从小到大排，并提取索引

            # 建立映射：中心小的赋0，中心大的赋1
            flag1 = np.zeros_like(idx)
            flag1[idx] = np.arange(len(idx))  # 默认起点0，步长1，输出数列

            # 1. 保存到时间序列矩阵 (对应的时刻填入 0 或 1)
            spike_trains1[spikes_indices, i] = flag1[_kmeans.labels_]
            # 2. 保存中心值 (这里加入了 [idx] 进行重排！)
            # 这样确保保存进去的第0个永远是较小值，第1个永远是较大值
            cluster_centers1[:, i] = _kmeans.cluster_centers_[idx]

            if np.unique(spike_trains1[:, i]).shape[0] != 2:
                list_sil1[i, 0] = 0

            else:
                _sil = silhouette_score(spikes, _kmeans.labels_, random_state=None)
                print(f"MU {i}: {_sil}")
                list_sil1[i, 0] = _sil

        for i in range(emg_mu_squared2.shape[1]):
            # 提取波峰数据
            spikes_indices = np.nonzero(emg_mu_peak2[:, i])[0]
            spikes = emg_mu_peak2[spikes_indices, i].reshape((-1, 1))

            # K-Means 聚类
            _kmeans = KMeans(n_clusters=2, max_iter=10000, random_state=None)
            _kmeans.fit(spikes)

            # --- 关键排序步骤 (用于矫正标签) ---
            # idx: [0, 1] 或 [1, 0]，指示从小到大的顺序
            idx = np.argsort(_kmeans.cluster_centers_.sum(axis=1))  # 从小到大排，并提取索引

            # 建立映射：中心小的赋0，中心大的赋1
            flag1 = np.zeros_like(idx)
            flag1[idx] = np.arange(len(idx))  # 默认起点0，步长1，输出数列

            # 1. 保存到时间序列矩阵 (对应的时刻填入 0 或 1)
            spike_trains2[spikes_indices, i] = flag1[_kmeans.labels_]
            # 2. 保存中心值 (这里加入了 [idx] 进行重排！)
            # 这样确保保存进去的第0个永远是较小值，第1个永远是较大值
            cluster_centers2[:, i] = _kmeans.cluster_centers_[idx]

            if np.unique(spike_trains2[:, i]).shape[0] != 2:
                list_sil2[i, 0] = 0

            else:
                _sil = silhouette_score(spikes, _kmeans.labels_, random_state=None)
                print(f"MU {i}: {_sil}")
                list_sil2[i, 0] = _sil

        valid_index_mu1 = np.where(np.all(list_sil1 >= thre_sil, axis=1))[0]
        st_valid1 = spike_trains1[:, valid_index_mu1.tolist()]
        center_valid1 = cluster_centers1[:, valid_index_mu1.tolist()]

        valid_index_mu2 = np.where(np.all(list_sil2 >= thre_sil, axis=1))[0]
        st_valid2 = spike_trains2[:, valid_index_mu2.tolist()]
        center_valid2 = cluster_centers2[:, valid_index_mu2.tolist()]

        # file_name_f = f'zwb_valid_index_f_{num_of_motion}.csv'
        # file_name_e = f'zwb_valid_index_e_{num_of_motion}.csv'
        file_name_f = f'S02_valid_index_T{num_of_motion}_dev0.csv'
        file_name_e = f'S02_valid_index_T{num_of_motion}_dev1.csv'

        full_path_f = os.path.join(save_file_path, file_name_f)
        full_path_e = os.path.join(save_file_path, file_name_e)

        np.savetxt(full_path_f, valid_index_mu1, delimiter=',')
        np.savetxt(full_path_e, valid_index_mu2, delimiter=',')

        # file_name_f = f'zwb_center_f_{num_of_motion}.csv'
        # file_name_e = f'zwb_center_e_{num_of_motion}.csv'
        file_name_f = f'S02_center_T{num_of_motion}_dev0.csv'
        file_name_e = f'S02_center_T{num_of_motion}_dev1.csv'

        full_path_f = os.path.join(save_file_path, file_name_f)
        full_path_e = os.path.join(save_file_path, file_name_e)

        np.savetxt(full_path_f, center_valid1.squeeze(axis=-1), delimiter=',')
        np.savetxt(full_path_e, center_valid2.squeeze(axis=-1), delimiter=',')
        # ====== ✅ 新增：保存完整信息（核心）======

        # 1. 保存所有MU的silhouette
        np.save(os.path.join(save_file_path, f'S02_sil_T{num_of_motion}_dev0.npy'), list_sil1)
        np.save(os.path.join(save_file_path, f'S02_sil_T{num_of_motion}_dev1.npy'), list_sil2)

        # 2. 保存所有MU的spike train（64个）
        np.save(os.path.join(save_file_path, f'S02_spike_T{num_of_motion}_dev0.npy'), spike_trains1)
        np.save(os.path.join(save_file_path, f'S02_spike_T{num_of_motion}_dev1.npy'), spike_trains2)

        # 3. 保存所有MU的聚类中心（未筛选）
        np.save(os.path.join(save_file_path, f'S02_center_all_T{num_of_motion}_dev0.npy'), cluster_centers1)
        np.save(os.path.join(save_file_path, f'S02_center_all_T{num_of_motion}_dev1.npy'), cluster_centers2)

        print('end kmeans')

        plotspikes(st_valid1[:, :], title=f'dev0_T{num_of_motion}')
        plotspikes(st_valid2[:, :], title=f'dev1_T{num_of_motion}')
        plt.close('all')