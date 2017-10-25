class MiniMeTokenState {
  constructor(minimeToken) {
    this.$token = minimeToken;
  }

  async getState() {
    const st = {
      balances: {},
    };

    const res = await Promise.all([
      this.$token.name(),
      this.$token.decimals(),
      this.$token.controller(),
      this.$token.totalSupply(),
      this.$token.parentToken(),
      this.$token.controller(),
      this.$token.parentSnapShotBlock(),
      this.$token.$web3.eth.getAccounts(),
    ]);

    st.name = res[0];
    st.decimals = res[1];
    st.controller = res[2];
    st.totalSupply = res[3];
    st.parentToken = res[4];
    st.controller = res[5];
    st.parentSnapShotBlock = res[6];
    const accounts = res[7];

    const calls = accounts.map(account => this.$token.balanceOf(account));

    const balances = await Promise.all(calls);

    for (let i = 0; i < accounts.length; i += 1) {
      st.balances[accounts[i]] = balances[i];
    }

    return st;
  }
}

module.exports = MiniMeTokenState;

