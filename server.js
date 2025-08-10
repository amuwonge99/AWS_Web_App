const express = require('express');
const app = express();
const port = 5000;

app.get('/', (req, res) => {
  res.status(200).send('This is my Practical Week solution!');
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
