const express = require("express");
function makeApp(database){
    const app = express();
    app.use(express.json())
    app.post("/", async (req,res) => {
        const {username, password} = req.body;
        if (!password || !username){
            res.sendStatus(400)
            return
        }
        const newUser = await database.createUser(username,password);
        res.status(200).json(newUser)
    })

    return app
}

function add(a, b){
    return a + b;
}

function subtract(a, b){
    return a - b;
}

function multiply(a, b){
    return a * b;
}

function divide(a, b){
    return a / b;
}


module.exports = makeApp, add, subtract, multipy, divide