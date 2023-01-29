const dotenv = require('dotenv').config();
const ganache = require('ganache-cli');



const server = ganache.server({
  logger: console,
  mnemonic: process.env.MNEMONIC,
});

const port = 8545;
server.listen(port, (error, blockchain) => {
  if (error) {
    console.error(error);
  }

  console.log(blockchain.personal_accounts);
});
