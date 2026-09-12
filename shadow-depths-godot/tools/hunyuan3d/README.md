# 混元 3D：三职业基础身体生成

已准备男性战士、女性法师、女性弓箭手三个独立图生任务。输入只使用本轮生成的单人基础身体图，不读取或复用本机 3D 模型。

当前状态：本地请求检查与七项离线测试通过；缺少腾讯云凭据，尚未提交任何真实生成任务。离线测试中的 GLB/任务响应是测试替身，不是生成成果。

## 接通账号

先在腾讯云开通混元生 3D API 服务，并准备拥有相应接口调用权限的 SecretId / SecretKey。官方流程见[快速入门](https://cloud.tencent.com.cn/document/product/1804/120757)。网页端登录不等于当前命令行已有 API 凭据。

在你自己的终端执行（提示输入不会回显，不要把密钥发到聊天中）：

```sh
python3 /Users/weihu/AI/ShadowDepths/shadow-depths-godot/tools/hunyuan3d/generate.py configure
```

此命令仅将凭据保存到项目内 `.hunyuan3d/credentials.json`，文件权限为 0600，该目录已加入 Git 忽略；不会发起云端任务。也支持进程环境中的 TENCENTCLOUD_SECRET_ID / TENCENTCLOUD_SECRET_KEY，以及临时凭据的 TENCENTCLOUD_SESSION_TOKEN。地域默认 ap-guangzhou，可用 TENCENTCLOUD_REGION 指定。

## 执行

从仓库根目录执行：

```sh
python3 shadow-depths-godot/tools/hunyuan3d/generate.py plan
python3 shadow-depths-godot/tools/hunyuan3d/generate.py submit
python3 shadow-depths-godot/tools/hunyuan3d/generate.py poll --wait-seconds 600
```

plan 仅检查本地输入。submit 为 jobs.json 中尚未提交的任务逐个发起请求，记录 JobId。poll 查询原任务并下载返回的 GLB；单次轮询仍在运行时返回 2，可再次 poll。脚本使用 Python 标准库，不需要安装 SDK。

首批选择 Model=3.1、GenerateType=Normal、EnablePBR=true、FaceCount=100000，以保留写实源模型细节。GLB 是接口默认返回格式之一，没有把 GLB 错写入仅接受额外格式的 ResultFormat。参数依据[专业版提交接口](https://cloud.tencent.com/document/product/1804/123447)；状态与输出依据[查询接口](https://cloud.tencent.com/document/product/1804/123448)。

## 续跑与结果

任务状态保存在 `.hunyuan3d/state.json`。同一输入和参数不会重复提交；已下载成果缺失时，会查询原任务重新下载。输入发生变化则要求新版本资产 ID，避免混淆旧结果。

请求中断且未拿到 JobId 时标为 SUBMISSION_UNRESOLVED，不自动重试提交。需要从腾讯云 API Inspector 确认实际 JobId，再执行：

```sh
python3 shadow-depths-godot/tools/hunyuan3d/generate.py adopt --asset warrior_male_base_v1 --job-id VERIFIED_JOB_ID
```

接口结果链接有时效，应及时下载。已存在的 JobId 不可被 adopt 覆盖；失败任务也不会自动重新生成。

下载目录为 `assets/models/realistic/hunyuan_raw/`。脚本检查 GLB 容器、网格存在、外部依赖，并记录哈希与 mesh/skin/animation 数量；这不是完整 glTF 验证器。下载后的文件状态仍是原始模型，未经骨骼、换装或游戏运行验收。

下一阶段：修复拓扑和隐藏面 → 按职业体型制作独立衣甲 → 统一骨架与权重 → 独立武器挂点 → 三套动作 → 游戏装配。混元还提供[组件拆分与绑骨接口](https://cloud.tencent.cn/document/api/1804/120838)，但不能假定自动拆分已经满足服装版型、遮挡和权重规范；生成结果需逐件验证。

## 离线测试

```sh
python3 -m unittest discover -s shadow-depths-godot/tools/hunyuan3d -p 'test_*.py' -v
```

覆盖三职业输入不同、缺少认证不提交、请求中断不重复提交、续跑及参数变更保护、损坏 GLB 拒绝、生成完成不冒称已绑定，以及签名输入敏感性。尚未通过真实账号验证接口签名或模型生成质量。
