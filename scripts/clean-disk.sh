#!/usr/bin/env sh

# 清理硬盘空间，删除不需要的文件

# Xcode
dir=/Users/mli/Library/Developer/Xcode/DerivedData
echo "删除Xcode的生成文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除Xcode的生成文件 done"

# Docker
dir=/Users/mli/Library/Containers/com.docker.docker/Data/log
echo "删除docker日志文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除docker日志文件 done"

# 微信
dir=/Users/mli/Library/Containers/com.tencent.xinWeChat/Data/Library/Caches
echo "删除微信cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除微信cache文件 done"

# 网易邮箱
dir=/Users/mli/Library/Containers/com.netease.macmail/Data/Library/Caches
echo "删除网易邮箱cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除网易邮箱cache文件 done"

# 网易云音乐
dir=/Users/mli/Library/Containers/com.netease.163music/Data/Caches
echo "删除网易云音乐cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除网易云音乐cache文件 done"

# Apple Store
dir=/Users/mli/Library/Containers/com.apple.appstore/Data/Library/Caches
echo "删除Apple Store cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除Apple Store cache文件 done"

# Library
dir=/Users/mli/Library/Caches
echo "删除Library cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除Library cache文件 done"

dir=/Users/mli/Library/Logs
echo "删除Library日志文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除Librar日志文件 done"

# iCloud
dir="/Users/mli/Library/Mobile Documents/com~apple~CloudDocs"
echo "删除iCloud文件:$(du -sh "$dir"|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除iCloud文件 done"

# gradle
dir=/Users/mli/.gradle/caches
echo "删除gradle cache文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除gradle cache文件 done"

# System
# dir=/System/Library/Caches
# echo "删除System cache文件:$(du -sh $dir|cut -f 1) ..."
# #rm -rf $dir/*.*
# echo "删除System cache文件 done"

# private
dir=/private/var/log
echo "删除private日志文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除private日志文件 done"

dir=/private/tmp
echo "删除private tmp文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除private tmp文件 done"

# Library
# dir=/Library/Caches
# echo "删除Library cache文件:$(du -sh $dir|cut -f 1) ..."
# #rm -rf $dir/*.*
# echo "删除Library cache文件 done"

dir=/Library/Logs
echo "删除Library日志文件:$(du -sh $dir|cut -f 1) ..."
#rm -rf $dir/*.*
echo "删除Library日志文件 done"
