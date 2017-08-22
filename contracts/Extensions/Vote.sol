pragma solidity ^0.4.13;

import '../Standards/ISnapshotToken.sol';

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

    ISnapshotToken public TOKEN;
    uint256 public SNAPSHOT;
    bytes32[] public CHOICE_HASHES;

    string[] public choices;
    uint256[] totals;

    // Note: we use hashes because Solidity currently does not support passing
    //     string[] as an argument for external functions.
    function Vote(
        ISnapshotToken token,
        bytes32[] choiceHashes
    ) {
        TOKEN = token;
        SNAPSHOT = token.createSnapshot();
        CHOICE_HASHES = choiceHashes;
        choices.length = CHOICE_HASHES.length;
    }

    function initChoice(uint index, string choice)
    {
        require(index < CHOICE_HASHES.length);
        require(keccak256(choice) == CHOICE_HASHES[index]);
        choices[index] = choice;
    }

    function vote(uint256[] votes)
        public
    {
    }
}
