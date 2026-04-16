#!/bin/bash

#SBATCH --job-name=SLOSS-GRFE            # 任务名称
#SBATCH --account=project_2018377        # 使用有额度的项目账号: project_2018377  
#SBATCH --partition=large                # 使用 Puhti 的大规模分区
#SBATCH --nodes=5                        # 节点数量 nodes=1
#SBATCH --ntasks-per-node=36             # 每节点MPI进程数
#SBATCH --time=72:00:00                  # 预计运行时间 72 小时
#SBATCH --mem-per-cpu=3G                 # 每个核心分配 3GB 内存（根据你的模拟规模调整）
#SBATCH --output=/scratch/project_2018377/ljianhao/SLOSS_GRFE/rep=0/job_%j.out # 日志存放在SLOSS_GRFE项目

echo "Starting python run at $(date)"

module load gcc/11.3.0 openmpi/4.1.4
source /projappl/project_2018377/miniconda/bin/activate
conda activate MetaIBM

cd /scratch/project_2018377/ljianhao/MetaIBM/MetaIBM-3.3.1/experiments
srun python mpi_running_GRFE.py

echo "Finished python run at $(date)"
