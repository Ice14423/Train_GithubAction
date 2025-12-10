const request = require("supertest");
const { makeApp,add,subtract,multiply,divide } = require("../src/app.js");


const mockCreateUser = jest.fn();
const mockDatabase = {};
mockDatabase.createUser = mockCreateUser;
const app = makeApp(mockDatabase);

test("should save the username and password to the database", async () => {
    const bodyData = { username: "username1", password: "password1"}
    //ให้ mockCreateUser ส่งข้อมูล id usrname และ password กลับไปเมื่อถูกเรียกใช้งาน
    mockCreateUser.mockResolvedValue({ id: 1, ...bodyData });
    const response = await request(app).post("/").send(bodyData);
    expect(mockCreateUser.mock.calls[0][0]).toBe(bodyData.username);
    expect(mockCreateUser.mock.calls[0][1]).toBe(bodyData.password);
    expect(response.statusCode).toBe(200); // ตรวจสอบว่า status code = 200
    expect(response.body.id).toBe(1); // ตรวจสอบว่า id = 1
    expect(response.body.username).toBe(bodyData.username);
    expect(response.body.password).toBe(bodyData.password);
  });

/* ------------------ TEST: add ------------------ */
test("add() should work correctly", () => {
    expect(add(5, 3)).toBe(8);
    expect(add(-1, 1)).toBe(0);
});

/* ------------------ TEST: subtract ------------------ */
test("subtract() should work correctly", () => {
    expect(subtract(10, 3)).toBe(7);
    expect(subtract(5, 8)).toBe(-3);
});

/* ------------------ TEST: multiply ------------------ */
test("multiply() should work correctly", () => {
    expect(multiply(4, 5)).toBe(20);
    expect(multiply(0, 100)).toBe(0);
});

/* ------------------ TEST: divide ------------------ */
test("divide() should work correctly", () => {
    expect(divide(10, 2)).toBe(5);
    expect(divide(9, 3)).toBe(3);
});

/* ------------------ TEST: divide by zero ------------------ */
test("divide() should throw when dividing by zero", () => {
    expect(() => divide(10, 0)).toThrow("Cannot divide by zero");
});