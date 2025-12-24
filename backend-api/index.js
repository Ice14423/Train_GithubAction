const express = require('express');
const serverless = require('serverless-http');
const cors = require('cors');
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");

const app = express();
app.use(express.json());
app.use(cors()); // เปิด CORS ให้ React เรียกได้

const client = new DynamoDBClient({ region: "ap-southeast-1" });
const dynamo = DynamoDBDocumentClient.from(client);
const TABLE_NAME = "StudentGrades"; // ชื่อ Table ที่สร้างใน Terraform

// API 1: บันทึกเกรด
app.post('/grades', async (req, res) => {
  const { StudentID, Subject, Score, Grade } = req.body;
  try {
    await dynamo.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: { StudentID, Subject, Score, Grade }
    }));
    res.json({ message: "Saved successfully!" });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Could not save data" });
  }
});

// API 2: ดึงเกรดทั้งหมด
app.get('/grades', async (req, res) => {
  try {
    const result = await dynamo.send(new ScanCommand({ TableName: TABLE_NAME }));
    res.json(result.Items);
  } catch (error) {
    res.status(500).json({ error: "Could not fetch data" });
  }
});

module.exports.handler = serverless(app);