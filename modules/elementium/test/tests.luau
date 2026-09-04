local mock = require "./mock"
local storage = require "../src/shared/storage"
local task = require "../src/shared/task"
local testkit = require "@vendor/testkit"

local TEST, CASE, CHECK, FINISH = testkit.test()

storage.mock(mock.DataStoreService)

TEST("storage", function()
	do
		CASE "create session"
		local session = storage.initialize_raw(math.random(0, 1000))
		CHECK(session)
		CHECK(session.data)
	end

	local session = storage.initialize_raw(math.random(0, 1000))

	do
		CASE "lock session"
		session:lock()
		CHECK(session._.locked)
	end

	do
		CASE "steal lock"

		storage.owner "test123"
		session._.locked = false

		CHECK(session._.locked == false)
		session:lock()

		local slim = 1 / 1024

		for i, delay in { 1, 2, 4, 8, 16 } do
			task.step(delay - slim)
			CHECK(session._.attempt == i)
			CHECK(session._.locked == false)

			task.step(slim)
			CHECK(session._.attempt == i + 1)
			CHECK(session._.locked == (i == 5))
		end
	end

	do
		CASE "patch & update"

		local expected = 200
		local n = 0

		local function increment_shards(data: storage.Store, n: number)
			data.shards += n
			return data
		end

		local function fn(value: storage.Store)
			n += 1
			print("expected", expected, value.shards)
		end

		session:updated(fn)
		CHECK(n == 1)
		expected += 10
		session:patch(increment_shards, 10)
		CHECK(n == 2)
		expected += 10
		session:patch(increment_shards, 10)
		CHECK(n == 3)

		session:commit()
		CHECK(session.store:GetAsync(session.key).data.shards == expected)
	end
end)

FINISH()
