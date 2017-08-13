import './ISnapshotToken.sol';

// https://en.wikipedia.org/wiki/Comparison_of_electoral_systems

// https://en.wikipedia.org/wiki/Arrow%27s_impossibility_theorem
// https://en.wikipedia.org/wiki/Gibbard%E2%80%93Satterthwaite_theorem

// * Votes are public
// * Voting is weighed by amount of tokens owned
// * Votes can be changed
// *

// Cardinal systems are a natural fit for a token based voting system.
// * https://en.wikipedia.org/wiki/Approval_voting
// * https://en.wikipedia.org/wiki/Majority_judgment
// → https://en.wikipedia.org/wiki/Range_voting

// TODO: Implement Range voting with:
// * Votes proportional to shares (i.e. one vote per share)
// * Proxy voting: ability to delegate voting power
// * Ability to trade voting power (is this the same as above?)

// TODO:

contract Vote {

    ISnapshotToken public constant TOKEN;
    uint256 public constant SNAPSHOT;
    string[] public constant CHOICES;

    uint256[] totals;

    Vote(ISnapshotToken token, string[] options)
    {
        TOKEN = token;
        SNAPSHOT = token.createSnapshot();
        OPTIONS = options;
    }

    function vote(uint256[] votes)
        public
    {
    }
}
