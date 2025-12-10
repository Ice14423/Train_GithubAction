const request = require("supertest");
const makeApp = require("./app.js");

const mockCreateUser = jest.fn();
const mockDatabase = {};
mockDatabase.createUser = mockCreateUser;
const app = makeApp(mockDatabase);

test("should save the username and password to the database", async () => {
    const bodyData = { username: "username1", password: "password1"}
    //ให้ mockCreateUser ส่งข้อมูล id usrname และ password กลับไปเมื่อถูกเรียกใช้งาน
    mockCreateUser.mockResolvedValue({ id: 2, ...bodyData });
    const response = await request(app).post("/").send(bodyData);
    expect(mockCreateUser.mock.calls[0][0]).toBe(bodyData.username);
    expect(mockCreateUser.mock.calls[0][1]).toBe(bodyData.password);
    expect(response.statusCode).toBe(200); // ตรวจสอบว่า status code = 200
    expect(response.body.id).toBe(1); // ตรวจสอบว่า id = 1
    expect(response.body.username).toBe(bodyData.username);
    expect(response.body.password).toBe(bodyData.password);
  });