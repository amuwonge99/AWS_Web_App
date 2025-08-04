const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('This is our Practical Week solution. Brought to you by Group One!');
});

app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
