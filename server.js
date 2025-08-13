const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.status(200).send('This is my Practical Week solution!');
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});
console.log("App is starting...");

process.on('uncaughtException', err => {
  console.error('Uncaught Exception:', err);
});


app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
