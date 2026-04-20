#!/bin/bash

#SBATCH --job-name=SLOSS-GRFE-asexual    # 任务名称
#SBATCH --account=project_2018377        # 使用有额度的项目账号: project_2018377  
#SBATCH --partition=large                # 使用 Puhti 的大规模分区
#SBATCH --nodes=25                       # 节点数量 nodes=25
#SBATCH --ntasks-per-node=36             # 每节点MPI进程数
#SBATCH --mem-per-cpu=3G                 # 申请该节点的最大可用内存
#SBATCH --time=72:00:00                  # 预计运行时间 72 小时
#SBATCH --output=/scratch/project_2018377/ljianhao/SLOSS_GRFE/job_%j.out # 日志存放在SLOSS_GRFE项目

echo "Starting python run at $(date)"

module load gcc/11.3.0 openmpi/4.1.4
source /projappl/project_2018377/miniconda/bin/activate
conda activate MetaIBM

cd /projappl/project_2018377/MetaIBM/MetaIBM-3.3.1/experiments
srun python -u mpi_running_GRFE_asexual.py

echo "Finished python run at $(date)"
