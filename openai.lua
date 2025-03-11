-- 作者阿泽，技术支持claude
-- OpenAI API 库 - 专为GG修改器设计
-- 作为单一函数提供，无需require导入
function CreateOpenAIClient(apiKey, baseUrl)
    local openai = {}
    
    -- OpenAI API基础URL（默认使用你提供的代理URL）
    baseUrl = baseUrl or "https://api.lzx1.top/v1"
    
    -- 确保提供有效的API密钥
    if not apiKey or type(apiKey) ~= "string" or apiKey == "" then
        error("必须提供有效的API密钥")
    end
    
    -- 辅助函数：解码URL中的Unicode转义字符
    local function decodeUnicodeEscapes(str)
        if not str or type(str) ~= "string" then
            return str
        end
        
        -- 替换常见的Unicode转义序列
        local replacements = {
            ["\\u0026"] = "&",
            ["\\u003d"] = "=",
            ["\\u003c"] = "<",
            ["\\u003e"] = ">",
            ["\\u0022"] = "\"",
            ["\\u0027"] = "'",
            ["\\u002f"] = "/",
            ["\\u002F"] = "/",
            ["\\u005c"] = "\\",
            ["\\u005C"] = "\\",
            ["\\u0020"] = " ",
            ["\\u003A"] = ":",
            ["\\u003a"] = ":",
            ["\\u003B"] = ";",
            ["\\u003b"] = ";",
            ["\\u002E"] = ".",
            ["\\u002e"] = ".",
            ["\\u002C"] = ",",
            ["\\u002c"] = ","
        }
        
        for escape, char in pairs(replacements) do
            str = str:gsub(escape, char)
        end
        
        -- 如果Lua 5.3+可以尝试使用utf8库处理其他Unicode转义序列
        local success, hasUtf8 = pcall(function() return utf8 ~= nil end)
        if success and hasUtf8 then
            str = str:gsub("\\u(%x%x%x%x)", function(hex)
                local codepoint = tonumber(hex, 16)
                if codepoint then
                    return utf8.char(codepoint)
                else
                    return ""
                end
            end)
        end
        
        return str
    end
    
    -- 替换文本中的转义换行符为实际换行符
    function fixNewlines(text)
        if not text or type(text) ~= "string" then
            return text
        end
        
        -- 替换常见的转义序列
        text = text:gsub("\\n", "\n")
        text = text:gsub("\\r", "\r")
        text = text:gsub("\\t", "\t")
        
        return text
    end
    
    -- 用于将Lua表转换为JSON字符串的函数
    local function tableToJson(t)
        if type(t) ~= "table" then return tostring(t) end
        
        local function serializeValue(v)
            if type(v) == "table" then
                return tableToJson(v)
            elseif type(v) == "string" then
                return string.format('"%s"', v:gsub('"', '\\"'):gsub('\n', '\\n'))
            elseif type(v) == "boolean" or type(v) == "number" then
                return tostring(v)
            elseif v == nil then
                return "null"
            else
                return string.format('"%s"', tostring(v))
            end
        end
        
        local isArray = true
        local maxIndex = 0
        
        -- 检查是否为数组
        for k, _ in pairs(t) do
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        local result = {}
        
        if isArray then
            -- 数组格式
            for i = 1, maxIndex do
                table.insert(result, t[i] ~= nil and serializeValue(t[i]) or "null")
            end
            return "[" .. table.concat(result, ",") .. "]"
        else
            -- 对象格式
            for k, v in pairs(t) do
                if type(k) == "string" then
                    table.insert(result, string.format('"%s":%s', k, serializeValue(v)))
                else
                    table.insert(result, string.format('"%s":%s', tostring(k), serializeValue(v)))
                end
            end
            return "{" .. table.concat(result, ",") .. "}"
        end
    end
    
    -- 用于将JSON字符串解析为Lua表的函数
    local function jsonToTable(jsonStr)
        -- 简单的JSON解析实现
        if not jsonStr or jsonStr == "" then
            return nil
        end
        
        -- 确保jsonStr是字符串
        if type(jsonStr) ~= "string" then
            return nil
        end
        
        -- 对jsonStr进行预处理，解码Unicode转义字符
        jsonStr = decodeUnicodeEscapes(jsonStr)
        
        -- 基本类型处理
        if jsonStr == "null" then
            return nil
        elseif jsonStr == "true" then
            return true
        elseif jsonStr == "false" then
            return false
        elseif tonumber(jsonStr) then
            return tonumber(jsonStr)
        end
        
        -- 去除前后空白
        jsonStr = jsonStr:match("^%s*(.-)%s*$")
        
        -- 数组处理
        if jsonStr:sub(1, 1) == "[" and jsonStr:sub(-1) == "]" then
            local array = {}
            local arrContent = jsonStr:sub(2, -2)
            local index = 1
            
            -- 处理空数组
            if arrContent:match("^%s*$") then
                return array
            end
            
            local pos = 1
            local len = #arrContent
            
            while pos <= len do
                local value, nextPos
                
                -- 跳过空格
                local s, e = arrContent:find("^%s*", pos)
                if s then pos = e + 1 end
                
                if pos > len then break end
                
                -- 处理不同类型的值
                local char = arrContent:sub(pos, pos)
                
                if char == "{" or char == "[" then
                    -- 对象或数组
                    local stack = 1
                    local start = pos
                    pos = pos + 1
                    
                    while stack > 0 and pos <= len do
                        local c = arrContent:sub(pos, pos)
                        if c == "{" or c == "[" then
                            stack = stack + 1
                        elseif c == "}" or c == "]" then
                            stack = stack - 1
                        elseif c == '"' then
                            -- 跳过字符串
                            pos = pos + 1
                            while pos <= len do
                                if arrContent:sub(pos, pos) == '"' and arrContent:sub(pos-1, pos-1) ~= "\\" then
                                    break
                                end
                                pos = pos + 1
                            end
                        end
                        pos = pos + 1
                    end
                    
                    value = jsonToTable(arrContent:sub(start, pos - 1))
                elseif char == '"' then
                    -- 字符串
                    local start = pos
                    pos = pos + 1
                    
                    while pos <= len do
                        if arrContent:sub(pos, pos) == '"' and arrContent:sub(pos-1, pos-1) ~= "\\" then
                            break
                        end
                        pos = pos + 1
                    end
                    
                    value = arrContent:sub(start + 1, pos - 1):gsub('\\"', '"')
                    pos = pos + 1
                else
                    -- 数字、布尔值或null
                    local s, e, val = arrContent:find("([^,}%]]+)", pos)
                    if s then
                        pos = e + 1
                        val = val:match("^%s*(.-)%s*$") -- 去除前后空白
                        
                        if val == "null" then
                            value = nil
                        elseif val == "true" then
                            value = true
                        elseif val == "false" then
                            value = false
                        else
                            value = tonumber(val) or val
                        end
                    end
                end
                
                array[index] = value
                index = index + 1
                
                -- 跳过逗号和空格
                local s, e = arrContent:find("^%s*,%s*", pos)
                if s then
                    pos = e + 1
                else
                    break
                end
            end
            
            return array
        end
        
        -- 对象处理
        if jsonStr:sub(1, 1) == "{" and jsonStr:sub(-1) == "}" then
            local obj = {}
            local objContent = jsonStr:sub(2, -2)
            
            -- 处理空对象
            if objContent:match("^%s*$") then
                return obj
            end
            
            local pos = 1
            local len = #objContent
            
            while pos <= len do
                local key, value
                
                -- 跳过空格
                local s, e = objContent:find("^%s*", pos)
                if s then pos = e + 1 end
                
                if pos > len then break end
                
                -- 键必须是字符串
                if objContent:sub(pos, pos) == '"' then
                    local start = pos
                    pos = pos + 1
                    
                    while pos <= len do
                        if objContent:sub(pos, pos) == '"' and objContent:sub(pos-1, pos-1) ~= "\\" then
                            break
                        end
                        pos = pos + 1
                    end
                    
                    key = objContent:sub(start + 1, pos - 1):gsub('\\"', '"')
                    pos = pos + 1
                    
                    -- 跳过冒号和空格
                    local s, e = objContent:find("^%s*:%s*", pos)
                    if s then pos = e + 1 end
                    
                    -- 处理值
                    local char = objContent:sub(pos, pos)
                    
                    if char == "{" or char == "[" then
                        -- 对象或数组
                        local stack = 1
                        local start = pos
                        pos = pos + 1
                        
                        while stack > 0 and pos <= len do
                            local c = objContent:sub(pos, pos)
                            if c == "{" or c == "[" then
                                stack = stack + 1
                            elseif c == "}" or c == "]" then
                                stack = stack - 1
                            elseif c == '"' then
                                -- 跳过字符串
                                pos = pos + 1
                                while pos <= len do
                                    if objContent:sub(pos, pos) == '"' and objContent:sub(pos-1, pos-1) ~= "\\" then
                                        break
                                    end
                                    pos = pos + 1
                                end
                            end
                            pos = pos + 1
                        end
                        
                        value = jsonToTable(objContent:sub(start, pos - 1))
                    elseif char == '"' then
                        -- 字符串
                        local start = pos
                        pos = pos + 1
                        
                        while pos <= len do
                            if objContent:sub(pos, pos) == '"' and objContent:sub(pos-1, pos-1) ~= "\\" then
                                break
                            end
                            pos = pos + 1
                        end
                        
                        value = objContent:sub(start + 1, pos - 1):gsub('\\"', '"')
                        pos = pos + 1
                    else
                        -- 数字、布尔值或null
                        local s, e, val = objContent:find("([^,}%]]+)", pos)
                        if s then
                            pos = e + 1
                            val = val:match("^%s*(.-)%s*$") -- 去除前后空白
                            
                            if val == "null" then
                                value = nil
                            elseif val == "true" then
                                value = true
                            elseif val == "false" then
                                value = false
                            else
                                value = tonumber(val) or val
                            end
                        end
                    end
                    
                    obj[key] = value
                    
                    -- 跳过逗号和空格
                    local s, e = objContent:find("^%s*,%s*", pos)
                    if s then
                        pos = e + 1
                    else
                        break
                    end
                else
                    break -- 无效的JSON对象格式
                end
            end
            
            return obj
        end
        
        -- 如果不是对象或数组，返回nil
        return nil
    end
    
    -- 发送HTTP请求的函数
    local function makeRequest(method, endpoint, data, params)
        local url = baseUrl .. endpoint
        
        -- 添加查询参数
        if params and type(params) == "table" then
            local queryParams = {}
            for k, v in pairs(params) do
                table.insert(queryParams, k .. "=" .. tostring(v))
            end
            
            if #queryParams > 0 then
                url = url .. "?" .. table.concat(queryParams, "&")
            end
        end
        
        -- 设置请求头
        local headers = {
            ["Authorization"] = "Bearer " .. apiKey,
            ["Content-Type"] = "application/json"
        }
        
        -- 准备请求体
        local body = nil
        if data then
            body = tableToJson(data)
        end
        
        -- 发送请求
        local response = gg.makeRequest(url, headers, body)
        
        if not response then
            return nil, "API请求错误: 无响应"
        end
        
        -- 检查响应类型
        if type(response) == "table" then
            -- 检查是否有错误
            if response.code >= 400 then
                return nil, "API请求错误: " .. (response.message or "未知错误") .. " (代码: " .. response.code .. ")"
            end
            
            -- 从响应表中提取内容
            if not response.content or type(response.content) ~= "string" or response.content == "" then
                return nil, "API响应内容为空"
            end
            
            -- 使用content字段中的JSON字符串
            local success, result = pcall(jsonToTable, response.content)
            if not success then
                return nil, "JSON解析错误: " .. tostring(result)
            end
            
            return result, nil
        elseif type(response) == "string" then
            -- 如果是字符串，直接解析
            local success, result = pcall(jsonToTable, response)
            if not success then
                return nil, "JSON解析错误: " .. tostring(result)
            end
            
            return result, nil
        else
            -- 其他类型，返回错误
            return nil, "API响应格式错误: 期望表或字符串"
        end
    end
    
    -- 统一处理API错误的函数
    local function handleApiError(result)
        if not result then
            return "未知错误"
        elseif result.error then
            return result.error.message or "API错误"
        else
            return "未知错误"
        end
    end
    
    ---------------------------
    -- 核心API方法
    ---------------------------
    
    -- API方法：获取可用模型列表
    function openai.getModels()
        local result, err = makeRequest("GET", "/models")
        if err then
            return nil, err
        end
        
        return result.data or result, nil
    end
    
    -- API方法：获取特定模型的详细信息
    function openai.getModel(modelId)
        if not modelId then
            return nil, "必须提供模型ID"
        end
        return makeRequest("GET", "/models/" .. modelId)
    end
    
    -- API方法：创建聊天完成（chat completion）
    function openai.createChatCompletion(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.model then
            return nil, "必须提供模型ID"
        end
        
        if not params.messages or type(params.messages) ~= "table" or #params.messages == 0 then
            return nil, "必须提供至少一条消息"
        end
        
        -- 不支持流式输出
        params.stream = false
        
        return makeRequest("POST", "/chat/completions", params)
    end
    
    -- API方法：创建文本完成（text completion）
    function openai.createCompletion(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.model then
            return nil, "必须提供模型ID"
        end
        
        if not params.prompt then
            return nil, "必须提供提示文本"
        end
        
        -- 不支持流式输出
        params.stream = false
        
        return makeRequest("POST", "/completions", params)
    end
    
    -- API方法：创建嵌入（embeddings）
    function openai.createEmbedding(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.model then
            return nil, "必须提供模型ID"
        end
        
        if not params.input then
            return nil, "必须提供输入文本"
        end
        
        return makeRequest("POST", "/embeddings", params)
    end
    
    -- API方法：创建图像（DALL-E）
    function openai.createImage(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.prompt then
            return nil, "必须提供图像提示文本"
        end
        
        -- 设置默认参数
        params.n = params.n or 1
        params.size = params.size or "1024x1024"
        params.model = params.model or "dall-e-3"
        
        return makeRequest("POST", "/images/generations", params)
    end
    
    -- API方法：编辑图像
    function openai.editImage(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.image then
            return nil, "必须提供图像"
        end
        
        if not params.prompt then
            return nil, "必须提供图像编辑提示文本"
        end
        
        -- 设置默认参数
        params.n = params.n or 1
        params.size = params.size or "1024x1024"
        
        return makeRequest("POST", "/images/edits", params)
    end
    
    -- API方法：创建图像变体
    function openai.createImageVariation(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.image then
            return nil, "必须提供图像"
        end
        
        -- 设置默认参数
        params.n = params.n or 1
        params.size = params.size or "1024x1024"
        
        return makeRequest("POST", "/images/variations", params)
    end
    
    -- API方法：音频转录
    function openai.createTranscription(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.file then
            return nil, "必须提供音频文件"
        end
        
        if not params.model then
            params.model = "whisper-1"
        end
        
        return makeRequest("POST", "/audio/transcriptions", params)
    end
    
    -- API方法：音频翻译
    function openai.createTranslation(params)
        if not params then
            params = {}
        end
        
        -- 确保必要参数存在
        if not params.file then
            return nil, "必须提供音频文件"
        end
        
        if not params.model then
            params.model = "whisper-1"
        end
        
        return makeRequest("POST", "/audio/translations", params)
    end
    
    -- API方法：函数调用
    function openai.createToolCall(messages, tools, model)
        if not messages or type(messages) ~= "table" or #messages == 0 then
            return nil, "必须提供至少一条消息"
        end
        
        if not tools or type(tools) ~= "table" or #tools == 0 then
            return nil, "必须提供至少一个工具定义"
        end
        
        model = model or "gpt-3.5-turbo"
        
        local params = {
            model = model,
            messages = messages,
            tools = tools,
            tool_choice = "auto"
        }
        
        return openai.createChatCompletion(params)
    end
    
    ---------------------------
    -- 实用工具方法
    ---------------------------
    
    -- 适用于简单的聊天，返回纯文本回复
    function openai.chat(messages, model, temperature, maxTokens)
        model = model or "gpt-3.5-turbo"
        temperature = temperature or 0.7
        maxTokens = maxTokens or 1024
        
        if type(messages) == "string" then
            -- 如果传入的是字符串，则将其转换为消息数组
            messages = {
                {role = "user", content = messages}
            }
        elseif type(messages) ~= "table" then
            return nil, "消息必须是字符串或表格"
        end
        
        local params = {
            model = model,
            messages = messages,
            temperature = temperature,
            max_tokens = maxTokens
        }
        
        local result, err = openai.createChatCompletion(params)
        if err then
            return nil, err
        end
        
        -- 检查是否有有效回复
        if result and result.choices and result.choices[1] and result.choices[1].message then
            -- 处理响应中的转义字符，确保换行符正确显示
            local content = result.choices[1].message.content
            if content then
                content = fixNewlines(content)
            end
            return content, nil
        else
            return nil, "无法获取有效回复"
        end
    end
    
    -- 创建一个简单的对话助手
    function openai.createChatbot(systemPrompt, model, temperature)
    print(model, temperature)
        local chatbot = {}
        chatbot.model = model or "gpt-3.5-turbo"
        chatbot.temperature = temperature or 0.7
        chatbot.messages = {}
        
        -- 如果提供了系统提示，添加它
        if systemPrompt and type(systemPrompt) == "string" and systemPrompt ~= "" then
            table.insert(chatbot.messages, {role = "system", content = systemPrompt})
        end
        
        -- 向对话中添加用户消息并获取回复
        function chatbot:chat(userMessage, maxTokens)
            if not userMessage or userMessage == "" then
                return nil, "用户消息不能为空"
            end
            
            -- 添加用户消息
            table.insert(self.messages, {role = "user", content = userMessage})
            
            -- 获取回复
            local response, err = openai.chat(self.messages, self.model, self.temperature, maxTokens)
            
            if err then
                return nil, err
            end
            
            -- 确保换行符正确显示
            response = fixNewlines(response)
            
            -- 添加助手回复到历史记录
            table.insert(self.messages, {role = "assistant", content = response})
            
            return response, nil
        end
        
        -- 清除聊天历史
        function chatbot:clearHistory()
            self.messages = {}
            
            -- 如果之前有系统提示，重新添加
            if systemPrompt and type(systemPrompt) == "string" and systemPrompt ~= "" then
                table.insert(self.messages, {role = "system", content = systemPrompt})
            end
        end
        
        -- 获取当前聊天历史
        function chatbot:getHistory()
            return self.messages
        end
        
        -- 设置新的系统提示
        function chatbot:setSystemPrompt(newSystemPrompt)
            -- 检查是否已有系统提示
            local hasSystem = false
            for i, msg in ipairs(self.messages) do
                if msg.role == "system" then
                    -- 更新现有系统提示
                    self.messages[i].content = newSystemPrompt
                    hasSystem = true
                    break
                end
            end
            
            -- 如果没有系统提示，添加一个
            if not hasSystem and newSystemPrompt and newSystemPrompt ~= "" then
                table.insert(self.messages, 1, {role = "system", content = newSystemPrompt})
            end
        end
        
        return chatbot
    end
    
    -- 生成并保存图像
    function openai.generateImage(prompt, filename, size, model)
        if not prompt or prompt == "" then
            return nil, "必须提供图像提示"
        end
        
        size = size or "1024x1024"
        model = model or "dall-e-3"
        
        local params = {
            prompt = prompt,
            n = 1,
            size = size,
            model = model
        }
        
        local result, err = openai.createImage(params)
        if err then
            return nil, "图像生成失败: " .. err
        end
        
        -- 检查是否有有效回复
        if result and result.data and result.data[1] and result.data[1].url then
            -- 处理URL中的Unicode转义字符
            local imageUrl = decodeUnicodeEscapes(result.data[1].url)
            
            -- 如果提供了文件名，则保存图像
            if filename then
                -- 下载图像
                local response = gg.makeRequest(imageUrl, {}, nil)
                
                if response and response.content then
                    -- 尝试保存图像
                    local file = io.open(filename, "wb")
                    if file then
                        file:write(response.content)
                        file:close()
                        return {url = imageUrl, path = filename}, nil
                    else
                        return {url = imageUrl}, "图像保存失败"
                    end
                else
                    return {url = imageUrl}, "图像下载失败"
                end
            else
                return {url = imageUrl}, nil
            end
        else
            return nil, "无法获取有效的图像URL"
        end
    end
    
    -- GG修改器专用：显示AI生成的图像
    function openai.showImage(prompt, size, model)
        local result, err = openai.generateImage(prompt, nil, size, model)
        
        if err then
            gg.alert("图像生成失败: " .. err)
            return nil
        end
        
        -- 使用GG的方式展示图像
        if result and result.url then
            gg.toast("正在加载图像...")
            -- 确保URL已解码，不包含转义字符
            local url = result.url
            
            -- 尝试使用GG修改器的功能显示图像
            -- 这里需要根据GG修改器的实际API调整
            gg.showImage(url)
            return url
        else
            gg.alert("无法获取图像URL")
            return nil
        end
    end
    
    -- 对文本进行简单的自动分片处理
    function openai.chunkText(text, maxChunkSize)
        maxChunkSize = maxChunkSize or 4000
        
        if #text <= maxChunkSize then
            return {text}
        end
        
        local chunks = {}
        local start = 1
        
        while start <= #text do
            local endPos = math.min(start + maxChunkSize - 1, #text)
            
            -- 尝试在句子结束处分割
            if endPos < #text then
                local lastSentence = text:sub(endPos - 100, endPos):match(".*[。.!?]")
                if lastSentence then
                    endPos = endPos - 100 + #lastSentence
                end
            end
            
            table.insert(chunks, text:sub(start, endPos))
            start = endPos + 1
        end
        
        return chunks
    end
    
    -- 创建一个简单的文本摘要
    function openai.summarize(text, model)
        model = model or "gpt-3.5-turbo"
        
        local chunks = openai.chunkText(text)
        local summaries = {}
        
        for i, chunk in ipairs(chunks) do
            local prompt = "请对以下文本进行简短摘要:\n\n" .. chunk
            local summary, err = openai.chat(prompt, model)
            
            if err then
                return nil, "摘要生成失败: " .. err
            end
            
            table.insert(summaries, summary)
        end
        
        -- 如果有多个摘要，合并它们
        if #summaries > 1 then
            local combinedSummaries = table.concat(summaries, "\n\n")
            local finalPrompt = "请将以下多个摘要合并为一个连贯的摘要:\n\n" .. combinedSummaries
            
            return openai.chat(finalPrompt, model)
        else
            return summaries[1], nil
        end
    end
    
    -- 从文本中提取关键信息
    function openai.extractInfo(text, infoType, model)
        model = model or "gpt-3.5-turbo"
        
        local prompt = "请从以下文本中提取" .. infoType .. ":\n\n" .. text
        return openai.chat(prompt, model)
    end
    
    -- 简单工具函数：安全运行函数并处理错误
    function openai.safeRun(func, ...)
        local success, result, err = pcall(func, ...)
        if not success then
            return nil, "执行错误: " .. tostring(result)
        end
        return result, err
    end
    
    -- 返回创建的客户端对象
    return openai
end
