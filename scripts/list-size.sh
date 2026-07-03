###
 # @Author         : mli
 # @Email          : mli@poptown.io
 # @Description    : 
 # @FilePath       : /Users/mli/scripts/list-size.sh
 # @Date           : 2023-06-27 14:02:34
 # @LastEditTime   : 2023-06-28 20:05:45
 # @LastEditors    : mli
### 

 
#!/bin/bash

#
# 指定目录下，打印第一级的文件大小，或者目录则打印目录内文件的总大小，结果按照大小从大到小排列
#

# 指定目录
dir=$1
echo "指定目录: $dir" 

# 判断目录是否存在
if [ ! -d $dir ]; then
    echo "目录不存在"
    exit 1
fi

# 获取目录下所有文件和目录
files=$(ls $dir)

# 遍历所有文件和目录
for file in $files
do
   # 判断是否为目录
    if [ -d $dir/$file ]; then
        # 获取目录大小
        size=$(du -sh $dir/$file | awk '{print $1}')
        size_bytes=$(du -s $dir/$file | awk '{print $1}')
        echo "$file 目录大小为：$size $size_bytes bytes"
    else
        # 获取文件大小
        size=$(du -h $dir/$file | awk '{print $1}')
        size_bytes=$(du $dir/$file | awk '{print $1}')
        echo "$file 文件大小为：$size $size_bytes bytes"
    fi
done | sort -rn -t ' ' -k3


 