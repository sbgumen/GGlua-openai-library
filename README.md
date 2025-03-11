# 使用gglua对接openai模型

# OpenAI-GG修改器库使用文档
作者阿泽
QQ2585579144

## 简介

这是一个专为GG修改器设计的OpenAI API客户端库，以单个Lua函数形式提供，无需外部依赖，方便在GG修改器中使用。通过这个库，你可以在GG修改器脚本中轻松调用OpenAI的各种API，包括GPT聊天、文本生成、图像生成、音频转录等功能。

## 基本用法

### 初始化客户端

```lua
-- 导入库
load(gg.makeRequest('https://azapi.lzx1.top/lib/openai.lua').content)()
或者
loadfile('openai.lua')--导入本地库

-- 创建OpenAI客户端（使用你的API密钥）
local openai = CreateOpenAIClient("你的API密钥")

-- 如果需要使用自定义的API地址
local openai = CreateOpenAIClient("你的API密钥", "https://你的API地址/v1")

```
如果没有openai账号，可以使用[国内中转api](https://api.lzx1.top)
### 简单聊天示例

```lua
-- 发送一条消息并获取回复
local response, err = openai.chat("用一句话介绍GG修改器")
if err then
    print("聊天失败: " .. err)
else
    print("AI回复: " .. response)
end
```

### 创建对话机器人

```lua
-- 创建一个有记忆的聊天机器人
local chatbot = openai.createChatbot("你是一个游戏辅助专家，擅长帮助用户解决游戏问题。")

-- 与聊天机器人对话
local response, err = chatbot:chat("如何使用GG修改器修改游戏金币？")
if not err then
    gg.alert("AI回复: " .. response)
end

-- 继续对话（聊天机器人会记住上下文）
response, err = chatbot:chat("有什么注意事项？")
if not err then
    gg.alert("AI回复: " .. response)
end

-- 清除聊天历史
chatbot:clearHistory()
```

## API参考

### 核心API方法

#### 1. 聊天完成 (Chat Completions)

```lua
-- 基本聊天方法（推荐使用）
local response, err = openai.chat("你好", "gpt-3.5-turbo", 0.7, 1024)

-- 高级聊天配置
local messages = {
    {role = "system", content = "你是一个专业的游戏助手"},--系统
    {role = "user", content = "推荐几款好玩的手机游戏"}--用户
}

local params = {
    model = "gpt-3.5-turbo",--模型
    messages = messages,--对话
    temperature = 0.7,--模型温度
    max_tokens = 1024--最大token
}

local result, err = openai.createChatCompletion(params)

if not err then
if result and result.choices and result.choices[1] and result.choices[1].message then
    local reply = fixNewlines(result.choices[1].message.content)
    gg.alert(reply)
    end
end
```

#### 2. 文本完成 (Completions)

```lua
local params = {
    model = "text-davinci-003",
    prompt = "写一首关于游戏的诗",
    max_tokens = 100
}

local result, err = openai.createCompletion(params)
if not err then
    local text = result.choices[1].text
    gg.alert(text)
end
```

#### 3. 图像生成 (DALL-E)

```lua
-- 简单图像生成
local imageResult, err = openai.generateImage("一只可爱的猫咪玩电脑游戏")
if not err then
    gg.alert("图像URL: " .. imageResult.url)
end

-- 保存图像到文件
local imageResult, err = openai.generateImage("一只可爱的猫咪玩电脑游戏", "/sdcard/Download/cat_gaming.jpg")
if not err then
    gg.alert("图像已保存到: " .. imageResult.path)
end

-- 在GG修改器中显示图像
local imageUrl = openai.showImage("一只可爱的猫咪玩电脑游戏")
```

#### 4. 嵌入 (Embeddings)

```lua
local params = {
    model = "text-embedding-ada-002",
    input = "这是一段示例文本"
}

local result, err = openai.createEmbedding(params)
if not err then
    local embedding = result.data[1].embedding
    -- 可以使用这些嵌入向量进行相似度计算等
end
```

#### 5. 音频转录和翻译

```lua
-- 音频转录
local params = {
    file = "/sdcard/recording.mp3",
    model = "whisper-1"
}

local result, err = openai.createTranscription(params)
if not err then
    gg.alert("转录结果: " .. result.text)
end

-- 音频翻译
local params = {
    file = "/sdcard/recording.mp3",
    model = "whisper-1"
}

local result, err = openai.createTranslation(params)
if not err then
    gg.alert("翻译结果: " .. result.text)
end
```

#### 6. 模型信息

```lua
-- 获取所有可用模型
local models, err = openai.getModels()
if not err then
    local modelNames = {}
    for _, model in ipairs(models) do
        table.insert(modelNames, model.id)
    end
    gg.alert("可用模型: " .. table.concat(modelNames, ", "))
end

-- 获取特定模型信息
local model, err = openai.getModel("gpt-3.5-turbo")
if not err then
    gg.alert("模型信息: " .. model.id .. "\n所有者: " .. model.owned_by)
end
```

#### 7. 函数调用 (Tool Calls)

```lua
-- 定义工具
local tools = {
    {
        type = "function",
        function = {
            name = "get_game_info",
            description = "获取指定游戏的信息",
            parameters = {
                type = "object",
                properties = {
                    game_name = {
                        type = "string",
                        description = "游戏名称"
                    }
                },
                required = {"game_name"}
            }
        }
    }
}

-- 设置消息
local messages = {
    {role = "user", content = "告诉我关于王者荣耀的信息"}
}

-- 调用函数
local result, err = openai.createToolCall(messages, tools, "gpt-3.5-turbo")
if not err and result.choices and result.choices[1].message.tool_calls then
    local toolCall = result.choices[1].message.tool_calls[1]
    local functionName = toolCall.function.name
    local args = jsonToTable(toolCall.function.arguments)
    
    gg.alert("要调用的函数: " .. functionName .. "\n参数: " .. args.game_name)
    
    -- 这里可以根据函数名和参数执行实际操作
    -- 然后添加函数执行结果到消息中继续对话
end
```

### 实用工具方法

#### 1. 文本分块

```lua
-- 将长文本分成多个小块，以便处理超长文本
local chunks = openai.chunkText("这是一段很长的文本...", 2000)
for i, chunk in ipairs(chunks) do
    print("块 " .. i .. ": " .. chunk:sub(1, 20) .. "...")
end
```

#### 2. 文本摘要

```lua
-- 为长文本生成摘要
local longText = [[这里是一段很长的文本内容...]]
local summary, err = openai.summarize(longText)
if not err then
    gg.alert("摘要: " .. summary)
end
```

#### 3. 信息提取

```lua
-- 从文本中提取特定信息
local text = "联系方式：电话13800138000，地址：北京市海淀区中关村南大街5号"
local info, err = openai.extractInfo(text, "联系电话")
if not err then
    gg.alert("提取的信息: " .. info)
end
```

## 最佳实践

### 1. 错误处理

所有API调用都会返回两个值：结果和错误。始终检查错误以确保API调用成功：

```lua
local result, err = openai.chat("你好")
if err then
    gg.alert("出错了: " .. err)
    return
end
```

### 2. 节约令牌用量

1. 使用较小的模型和较短的提示词
2. 设置适当的max_tokens参数
3. 对于长文本，使用chunkText函数分块处理

```lua
-- 设置适当的max_tokens
local response, err = openai.chat("请简短回答", "gpt-3.5-turbo", 0.7, 100)
```

### 3. 保持对话上下文

使用createChatbot函数创建有记忆的聊天机器人，而不是单独的chat调用：

```lua
local chatbot = openai.createChatbot("你是一个游戏专家")
local response1 = chatbot:chat("什么是GG修改器？")
local response2 = chatbot:chat("它有什么功能？") -- 会记住上下文
```

### 4. 自定义系统提示

为聊天机器人设置好的系统提示，以获得更符合预期的回答：

```lua
local chatbot = openai.createChatbot([[
你是一个专业的游戏修改助手，熟悉GG修改器的使用方法。
请用简洁明了的语言解答问题，不要超过100字。
如果不确定答案，请直接说不知道，不要胡乱猜测。
]])
```

## 完整示例

### 游戏问答助手

```lua
-- 创建OpenAI客户端
local openai = CreateOpenAIClient("你的API密钥")

-- 创建聊天机器人
local chatbot = openai.createChatbot([[
你是一个专业的游戏修改助手，熟悉GG修改器的使用方法。
请用简洁明了的语言解答问题，不要超过100字。
]])

-- 创建简单菜单
function showMenu()
    local menu = gg.choice({
        "问游戏问题",
        "生成游戏图片",
        "清除聊天历史",
        "退出"
    }, nil, "GG-OpenAI助手")
    
    if menu == 1 then
        askQuestion()
    elseif menu == 2 then
        generateGameImage()
    elseif menu == 3 then
        chatbot:clearHistory()
        gg.toast("聊天历史已清除")
        showMenu()
    elseif menu == 4 then
        os.exit()
    end
end

-- 问问题功能
function askQuestion()
    local question = gg.prompt({"请输入你的问题"}, {""}, {"text"})
    if question and question[1] ~= "" then
        gg.toast("正在思考...")
        local response, err = chatbot:chat(question[1])
        if err then
            gg.alert("出错了: " .. err)
        else
            gg.alert(response)
        end
    end
    showMenu()
end

-- 生成游戏图片
function generateGameImage()
    local prompt = gg.prompt({"描述你想要的游戏图片"}, {"像素风格的冒险游戏场景"}, {"text"})
    if prompt and prompt[1] ~= "" then
        gg.toast("正在生成图片...")
        openai.showImage(prompt[1])
    end
    showMenu()
end

-- 启动应用
showMenu()
```

## 注意事项

1. **API密钥安全**：不要在公开脚本中包含你的API密钥，可以考虑让用户自己输入或使用加密存储。

2. **响应处理**：始终检查API调用返回的错误，并妥善处理异常情况。

3. **令牌限制**：请注意OpenAI API有使用限制，合理设置最大令牌数可以帮助控制费用。

4. **请求频率**：避免短时间内发送过多请求，以免触发API限制。

5. **内容政策**：确保你的应用符合OpenAI的使用政策，不要生成违规内容。

6. **文件权限**：在保存图像等文件时，确保GG修改器有适当的文件系统权限。

## 常见问题排查

1. **"API请求错误"**：检查你的API密钥是否正确，网络连接是否正常。

2. **"JSON解析错误"**：API返回的内容可能不是有效的JSON，可能是网络问题或API变更。

3. **"无法获取有效回复"**：检查请求参数是否正确，模型名称是否有效。

4. **应用卡顿**：API请求是同步的，可以考虑在后台线程中执行或添加加载提示。

5. **高API使用费用**：合理设置max_tokens参数，使用较小的模型，避免不必要的API调用。
