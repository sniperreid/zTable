local HttpService = game:GetService("HttpService")
--[[
	zTable is a luau table wrapper written by @Blueshell_Dev
]]--

local function deepCopy(original)
	local copy = {}
	
	for key, value in original do
		if typeof(value) == "table" then
			value = deepCopy(value)
		end
		
		copy[key] = value
	end
	
	return copy
end

local function deepSearch(original, scope, position)
	for i, v in original do
		if position and typeof(v) ~= "table" then continue end
		if typeof(v) == "table" and v._handlerListHead ~= nil then continue end
		
		if position and typeof(v) == "table" and v.ref and v.ref[position] == scope or v == scope then
			return i, v
		end
		
		if typeof(v) == "table" and v.ref then
			local searched = deepSearch(v.ref, scope, position)
			
			if searched then
				return i, searched
			end
		end
	end
end

local function shallowSearch(original, scope, position)
	for i, v in original do
		if position and typeof(v) ~= "table" then continue end
		if typeof(v) == "table" and v._handlerListHead ~= nil then continue end
		
		if position and typeof(v) == "table" and v.ref and v.ref[position] == scope or v == scope then
			return i, v
		end
	end
end

local Signal = require("@self/Signal")

local zTable = {}
zTable.__index = zTable

-- Creates a new zTable object.
function zTable.new(ref): zTableMalleable
	ref = deepCopy(ref or {})
	
	local formedTable = setmetatable({}, zTable)

	formedTable.Destroying = Signal.new()
	formedTable.Clearing = Signal.new()
	formedTable.Inserting = Signal.new()
	formedTable.Removing = Signal.new()
	formedTable.Changing = Signal.new()

	formedTable.ClassName = "zTable"
	formedTable.ref = zTable.transformReference(ref)

	return formedTable
end

function zTable.transformReference(vRef)
	for i, v in vRef do
		if typeof(v) == "table" and not v.ref then
			vRef[i] = zTable.new(v)
		end
	end

	return vRef
end 

export type formedTable = typeof(zTable.new {})

-- Fully destroys the zTable object
function zTable:Destroy()
	self.Destroying:Fire()
	
	self:Clear()
	
	table.clear(self)
	setmetatable(self, nil)
end

-- Clears the zTable metadata
function zTable:Clear()
	self.Clearing:Fire()
	
	table.clear(self.ref)
end

-- Returns the raw table from zTable metadata
function zTable:raw()
	local rawTable = {}
	
	for i, v in self.ref do
		if typeof(v) == "table" and v.ClassName == "zTable" then
			rawTable[i] = v:raw()
		else
			rawTable[i] = v
		end
	end
	
	return rawTable
end

-- Inserts object into zTable metadata
function zTable:Insert(Value: any?): zTableMalleable
	Value = Value or {}
	
	if typeof(Value) == "table" and Value.ClassName ~= "zTable" then
		Value = zTable.new(Value)
	end
	
	if typeof(Value) == "table" and Value.ref then
		self.Inserting:Fire(#self.ref + 1, Value.ref)
	else
		self.Inserting:Fire(#self.ref + 1, Value)
	end
	
	table.insert(self.ref, Value)
	
	return Value
end

-- Sets value in zTable metadata at key
function zTable:Set(key: string, Value: any?): zTableMalleable
	Value = Value or {}
	
	if typeof(Value) == "table" and Value.ClassName ~= "zTable" then
		Value = zTable.new(Value)
	end
	
	-- is a zTable
	if typeof(Value) == "table" and Value.ClassName == "zTable" then
		self.Changing:Fire(key, Value.ref)
	else
		self.Changing:Fire(key, Value)
	end
	
	self.ref[key] = Value
	
	return Value
end

-- Finds the position of an object in zTable metadata, at desired position
function zTable:Find(Value: any, init: number?)
	return table.find(self.ref, Value, init)
end

-- Pops an object if found in zTable metadata
function zTable:PopObject(Object: any)
	return self:Pop( self:Find(Object) )
end

-- Pops an object in zTable metadata at x position
function zTable:Pop(position: number?)
	if not position then return end
	
	local object
	
	if typeof(position) == "number" then
		object = table.remove(self.ref, position)
	else
		object = self.ref[position]

		self.ref[position] = nil
	end
	
	-- is a zTable
	if typeof(object) == "table" and object.ClassName == "zTable" then
		self.Removing:Fire(position, object.ref)
	else
		self.Removing:Fire(position, object)
	end
	
	return object
end

-- Loops through shallow objects and fires the callback with item info.
function zTable:ForEach(Callback: (any) -> ())
	for i, v in self:raw() do
		Callback(self, i, v)
	end
end

-- Loops through shallow objects (reverse order) and fires the callback with item info.
function zTable:ReverseSearch(Callback: (any) -> ())
	local z = self:raw()
	
	for i = #z, 1, -1 do
		Callback(self, i, z[i])
	end
end

-- Fills a new zTable metadata with x number of objects.
function zTable:Create(count: number, objects: any): formedTable
	return zTable.new( table.create(count, objects) )
end

-- Creates a new zTable with the same data as current table.
function zTable:Clone(): formedTable
	return zTable.new(self:raw())
end

-- Recursively search through every element of metadata or branch to find an object.
-- May also include a specific index/position for specific searches.
function zTable:DeepSearch(scope: any, position: any?): (number?, any?)
	return deepSearch(self.ref, scope, position)
end

-- Similar to DeepSearch, however does NOT recursively search.
-- Instead conducts a shallow search of metadata.
function zTable:ShallowSearch(scope: any, position: any?): (number?, any?)
	return shallowSearch(self.ref, scope, position)
end

-- Returns object from data
function zTable:Get(key: string | number): zTableMalleable
	return key and self.ref[key]
end

-- Increments a value in metadata by x or 1
function zTable:Increment(key: string | number, amount: number?)
	amount = amount or 1
	
	local value = self:Get(key)
	
	assert(value, `{key} is not a valid member of {self.ClassName}`)
	
	local vT = typeof(value)
	local aT = typeof(amount)
	
	assert(aT == "number", `number expected when adding value to {key}, got {aT}`)
	assert(vT == "number", `number expected when indexing Increment, got {vT}`)
	
	return self:Set(key, value + amount)
end

-- Encodes raw metadata into JSON
function zTable:JSONEncode()
	return HttpService:JSONEncode(self:raw())
end

-- Unpacks object
function zTable:Unpack()
	return table.unpack(self.ref)
end

export type zTableMalleable = typeof(setmetatable({} :: formedTable, zTable))

return table.freeze(zTable)
