#!/bin/bash
###
 # @Author         : mli
 # @Email          : mli@poptown.io
 # @Description    : 
 # @FilePath       : /Users/mli/scripts/compress-upload.sh
 # @Date           : 2024-03-11 12:31:12
 # @LastEditTime   : 2024-03-11 14:02:23
 # @LastEditors    : mli
### 

# 指定文件夹下全部的图片上传到指定的s3桶的指定路径下，上传的文件名保持和本地的一致
# upload-aws . bucket_name

# export PATH=~/bin:$PATH
# source ~/.bash_aliases
# pyenv shell 2

# 指定文件夹路径
# 如果命令行参数为空，使用当前路径，否则使用命令行参数作为文件夹路径
DIR=${1:-$(pwd)}
# 桶名
# YOUR_BUCKET_NAME=tarot-s3
YOUR_BUCKET_NAME=${2}
# 文件夹路径
YOUR_FOLDER_PATH=default

# 遍历文件夹中的所有文件
for file in $DIR/*; do
  # 检查文件是否为图片
  if [[ $file == *.jpg ]] || [[ $file == *.png ]]; then
    # 获取压缩后的文件名
    filename=$(basename $file)

    # 上传图片到S3
    aws s3 cp $file s3://$YOUR_BUCKET_NAME/$YOUR_FOLDER_PATH/$filename --region us-east-1
  fi
done
