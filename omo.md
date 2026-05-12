<!--
 * @Author         : midoll@midoll.ai
 * @Date           : 2026-05-12 15:57:24
 * @LastEditors    : Midoll
 * @LastEditTime   : 2026-05-12 17:35:47
 * @FilePath       : /omo.md
 * @Description    : 
 * 
-->
# 配置文件规则
[参考](https://github.com/code-yeongyu/oh-my-openagent/blob/dev/docs/reference/configuration.md#configuration-reference)

# 下面是必须填写的Agents和Categories列表

## Agents
Sisyphus
Metis

Prometheus
Atlas

Hephaestus
Oracle
Momus

Explore
Librarian
Multimodal-Looker
Sisyphus-Junior

## Categories
visual-engineering
artistry
ultrabrain
deep
quick
unspecified-high
unspecified-low
writing


# 要求: 
- 尽量使用所有的模型，即使就放在fallback中; 
- Provider配额从小到大依次为: 
  - kimi-for-coding 
  - openroute 
  - nvidia 
  - opencode 
  - longcat