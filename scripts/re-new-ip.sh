#!/bin/bash
###
 # @Author         : mli
 # @Email          : mli@poptown.io
 # @Description    : 
 # @FilePath       : /Users/mli/scripts/re-new-ip.sh
 # @Date           : 2024-02-28 17:11:11
 # @LastEditTime   : 2024-02-28 19:22:19
 # @LastEditors    : mli
### 
# 使用aws cli实现脚本，完成如下功能:
# 1. 在指定地域中遍历弹性ip列表，找到指定ec2的弹性ip，得到ip地址及分配id
# 2. 分配一个弹性ip，并关联到指定的ec2
# 3. 利用之前ip的分配id释放之前的ip
# 4. 返回新ip地址
# 脚本假设你已经在你的机器上安装并配置了AWS CLI，并且你有足够的权限来执行这些操作。如果你没有，你可能需要先设置AWS CLI并确保你的IAM用户有适当的权限

# 你的AWS配置文件名
# AWS_PROFILE=<aws-profile>

# AWS地域和EC2实例ID
REGION="ap-southeast-3"
INSTANCE_ID="i-09c5cd527ffdda09e"

# 获取指定EC2的弹性IP和分配ID
OLD_EIP_INFO=$(aws ec2 describe-addresses --region $REGION --filters "Name=instance-id,Values=$INSTANCE_ID" --query 'Addresses[0].[PublicIp,AllocationId]' --output text)
OLD_EIP=$(echo $OLD_EIP_INFO | awk '{print $1}')
OLD_ALLOCATION_ID=$(echo $OLD_EIP_INFO | awk '{print $2}')

echo "Old EIP: $OLD_EIP"
echo "Old Allocation ID: $OLD_ALLOCATION_ID"

# 分配新的弹性IP并关联到指定的EC2
NEW_EIP_INFO=$(aws ec2 allocate-address --region $REGION --domain vpc)
NEW_EIP=$(echo $NEW_EIP_INFO | jq -r .PublicIp)
NEW_ALLOCATION_ID=$(echo $NEW_EIP_INFO | jq -r .AllocationId)

echo "New EIP: $NEW_EIP"
echo "New Allocation ID: $NEW_ALLOCATION_ID"

aws ec2 associate-address --region $REGION --instance-id $INSTANCE_ID --allocation-id $NEW_ALLOCATION_ID > /dev/null 2>&1

# # 释放旧的弹性IP
aws ec2 release-address --region $REGION --allocation-id $OLD_ALLOCATION_ID

echo "Released old EIP: $OLD_EIP"

# 飞书webhook URL
WEBHOOK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/030f1dba-4b17-4165-8710-355c3d41b0b2"

# 新的IP地址
IP_ADDRESS=${NEW_EIP}

# 提醒的人
PERSON="刘翰男"

# 消息内容
MESSAGE="请将域名vpn.astroecho.io映射到新的IP:${IP_ADDRESS} @${PERSON}"

# 发送POST请求到飞书webhook
curl -X POST -H 'Content-Type: application/json' -d "{
    \"msg_type\": \"text\",
    \"content\": {
        \"text\": \"${MESSAGE}\"
    }
}" ${WEBHOOK_URL}
