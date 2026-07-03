###
 # @Author         : mli
 # @Email          : mli@poptown.io
 # @Description    : 
 # @FilePath       : /Users/mli/scripts/walk-tiny.sh
 # @Date           : 2023-06-29 11:10:46
 # @LastEditTime   : 2023-06-29 11:48:24
 # @LastEditors    : mli
### 

 
#!/bin/bash

pyenv shell 2

# 遍历指定目录，查找png后缀文件，执行tiny -f 命令
# function walk() {
#     for file in `ls $1`
#     do
#         if [ -d $1"/"$file ]
#         then
#             walk $1"/"$file
#         else
#             if [[ $file == *.png ]]
#             then
#                 echo "compressing $1/$file ..."
#                 tinypng -f $1"/"$file
#             fi
#         fi
#     done
# }
function walk_tiny() {
    # The while loop is used to iterate over each line of the output from the find command.
    # The IFS= part ensures that leading and trailing whitespace is preserved,
    # and the read -r file command reads each line into the file variable.
    find "$1" -type f -name "*.png" | while IFS= read -r file
    do
        echo "compressing $file ..."
        tinypng -f "$file"
    done
}

# 遍历当前目录
walk_tiny .

# 遍历指定目录，查找以"tiny_"为前缀, 以".png"为后缀的文件，即文件名为: tiny_xxx.png
# 改名为xxx.png并覆盖同目录的同名文件

function walk_mv() {
    # 使用find命令查找以"tiny_"为前缀，以".png"为后缀的文件
    find "$1" -type f -name "tiny_*.png" | while IFS= read -r file
    do
        # 获取文件名（不包含路径）
        filename=$(basename "$file")
        
        # 去掉前缀"tiny_"，得到新的文件名
        new_filename="${filename#tiny_}"
        
        # 获取文件所在目录
        directory=$(dirname "$file")
        
        # 构造新的文件路径
        new_filepath="$directory/$new_filename"
        
        # 输出操作信息
        echo "Renaming $file to $new_filepath ..."
        
        # 将文件重命名为新的文件名，并覆盖同目录下同名的文件
        mv "$file" "$new_filepath"
    done
}

# 调用遍历函数，传入指定目录作为参数
walk_mv .