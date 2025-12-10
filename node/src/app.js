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

module.exports = makeApp