local Username = "Admin"
local Password = "Password123"

local HttpService = game:GetService("HttpService")

local Secret = "SuperSecretKey"

local Response = request({
	Url = "http://127.0.0.1:8080/login",
	Method = "POST",
	Body = HttpService:JSONEncode({
		["Username"] = Username,
		["Password"] = Password
	}),
	Headers = {
		["Content-Type"] = "application/json"
	}
})

if (Response.StatusCode == 200) then
	local ResponseBody = HttpService:JSONDecode(Response.Body)
	local ResponseSignature = ResponseBody["Signature"]
	ResponseBody["Signature"] = nil

	local Signature = crypt.hash(Username .. ":" .. Password .. ":" .. Secret .. ":" .. string.gsub(HttpService:JSONEncode(ResponseBody), "%s+", ""), "sha256")
	
	if (ResponseSignature == Signature and ResponseBody.Success == true) then
		print("[SYSTEM] You have logged in successfully!")
	else 	
		print("[SYSTEM] Tampering detected.")
	end

elseif (Response.StatusCode == 401) then
	print("[SYSTEM] Invalid credentials.")
else
	print("[SYSTEM] Unknown error occurred.")
end
