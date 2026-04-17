import express from 'express';  

const app = express(); 

const PORT = 4000;  
//const PORT = 4000;  

app.get('/v1/', (req, res) => {     
    res.status(200).send('Hello World from App 1'); 
});  

// app.get('/v1/', (req, res) => {     
//     res.status(200).send('Hello World from App 2'); 
// });  

app.listen(PORT, () => {     
    console.log(`Server is running on port 4000`); 
});

// app.listen(PORT, () => {     
//     console.log(`Server is running on port 3000`); 
// });