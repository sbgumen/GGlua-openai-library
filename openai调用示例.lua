-- OpenAI API使用示例
-- 作者: 阿泽
-- 日期: 2025-03-11

-- 导入OpenAI库
-- 注意：请确保已将openai.lua文件保存到GG修改器可访问的路径
load(gg.makeRequest('https://azapi.lzx1.top/lib/openai.lua').content)()

-- 创建OpenAI客户端
local openai = CreateOpenAIClient("sk-J5CILOBtozLoapePqfgBUMQODDj68DRlRZtFOrkC5OibeEES", "https://api.lzx1.top/v1")

--示例获取可用模型
function getModels()
local models, err = openai.getModels()
if not err then
    local modelNames = {}
    for _, model in ipairs(models) do
        table.insert(modelNames, model.id)
    end
    gg.alert("可用模型: " .. table.concat(modelNames, ", "))
end
end


-- 示例1: 基本聊天对话
function testChat()
    gg.toast("正在与AI对话...")
    local response, err = openai.chat("用一句话介绍GG修改器的功能")
    
    if err then
        gg.alert("聊天失败: " .. err)
    else
        gg.alert("AI回复:\n" .. response)
    end
end

-- 示例2: 高级聊天对话
function seniorChat()
local messages = {
    {role = "system", content = "你是一个专业的游戏助手"},
    {role = "user", content = "推荐几款好玩的手机游戏"}
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
end





-- 示例3: 显示代码生成示例
function testCodeGeneration()
    gg.toast("正在生成代码...")
    local prompt = "编写一个GG修改器搜索脚本，用于查找并修改游戏中的金币数值"
    local response, err = openai.chat(prompt)
    
    if err then
        gg.alert("代码生成失败: " .. err)
    else
        gg.alert("AI生成的代码:\n" .. response)
    end
end

-- 示例4: 使用聊天机器人保持上下文对话
function askQuestion()

    local question = gg.prompt({"请输入你的问题，ai会记住这次对话"}, {""}, {"text"})
    if question and question[1] ~= "" then
        gg.toast("正在思考...")
        local response, err = chatbot:chat(question[1])
        if err then
            gg.alert("出错了: " .. err)
        else
            gg.alert(response)
            print(response)
        end
    end
end

-- 示例5: 生成图像
function testImageGeneration()

    local prompt = gg.prompt({"请描述你想要的图像"}, {"一只可爱的小狗在玩手机游戏"}, {"text"})
    
    if prompt and prompt[1] ~= "" then
        gg.toast("正在生成图像，请稍候...")
        local result, err = openai.generateImage(prompt[1])
        
        if err then
            gg.alert("图像生成失败: " .. err)
        else
            gg.toast("图像生成成功，正在显示...")
            gg.showUrl(result.url)
            -- 或者保存到文件
            -- local result = openai.generateImage(prompt[1], "/sdcard/Download/ai_image.jpg")
            -- gg.alert("图像已保存到: " .. result.path)
        end
    end
end


--初始化创建记忆
chatbot = openai.createChatbot(
"你是一个专业的游戏修改助手，熟悉GG修改器的使用方法。")--可用高级聊天对话配置
-- 主菜单


function Main()
local functions = {
    {name = "获取可用模型", func = getModels},
    {name = "基本聊天", func = testChat},
    {name = "高级聊天", func = seniorChat},
    {name = "代码生成", func = testCodeGeneration},
    {name = "记忆对话", func = askQuestion},
    {name = "清除记忆", func = function() chatbot:clearHistory()  end},
    {name = "图像生成", func = testImageGeneration},
    {name = "退出", func = function() os.exit() end},
}
    local menuOptions = {}
    for _, entry in ipairs(functions) do
        table.insert(menuOptions, entry.name)
    end
    local NS = gg.choice(menuOptions, 0, "openai库使用示例")
    
    if NS then
        local selectedFunction = functions[NS].func
        if selectedFunction then
            selectedFunction()
        end
    end
    NS1=0
end


while true do
	if gg.isVisible(true) then
    		NS1 = nil
    		gg.setVisible(false)
	end
	if NS1 == nil then
		Main()
	end
end