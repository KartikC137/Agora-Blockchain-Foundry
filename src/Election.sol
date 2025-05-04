// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBallot} from "./ballots/interface/IBallot.sol";
import {IResultCalculator} from "./resultCalculators/interface/IResultCalculator.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * @title Election Contract
 * @author KartikC137
 *
 * This Contract Manages each Election created by the ElectionFactory.
 * It handles the voting process, candidate management, and result calculation.
 *
 * @notice Cross - chain voting is not yet implemented
 */

contract Election is Initializable {
    //////////////////
    // Errors      ///
    //////////////////

    error NotOwner();
    error AlreadyVoted();
    error VotesUnavailable();
    error TotalVotesExceedNumberOfCandidates(
        uint256 candidateLength,
        uint256 totalVotes
    );
    error ElectionInactive();
    error ElectionActive();
    error ElectionEnded();
    error InvalidCandidateID();
    error InvalidCandidatesLength();
    error CandidateAlreadyRemoved(uint256 candidateId);
    error ResultsHaveAlreadyBeenDeclared(uint256[] winners);

    ////////////////////////////
    // Types Declarations    ///
    ////////////////////////////

    struct ElectionInfo {
        uint64 startTime;
        uint64 endTime;
        string name;
        string description;
    }

    struct Candidate {
        uint256 candidateID;
        string name;
        string description;
    }

    ////////////////////////
    // State Variables   ///
    ////////////////////////

    IBallot private ballot;
    IResultCalculator private resultCalculator;

    ElectionInfo public s_electionInfo;
    Candidate[] public s_candidates;

    mapping(address user => bool isVoted) public s_userVoted;

    address public s_factoryContract;
    address public s_owner;

    uint256[] public s_winners;
    uint256 public s_electionId;
    uint256 public s_resultType;
    uint256 public s_totalVotes;

    bool private s_electionEnded;
    bool public s_resultsDeclared;
    bool private s_ballotInitialized;

    //////////////
    // Events  ///
    //////////////

    event AddCandidate(string indexed name, string indexed description);
    event RemoveCandidate(uint256 indexed candidateId);
    event CastVote(address indexed voter);
    event CalculateFinalResult();
    event EndElection();

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != s_owner) revert NotOwner();
        _;
    }

    modifier electionInactiveCheck() {
        if (block.timestamp < s_electionInfo.startTime)
            revert ElectionInactive();
        _;
    }

    modifier electionStartedCheck() {
        if (block.timestamp > s_electionInfo.startTime) revert ElectionActive();
        _;
    }

    modifier electionEndedCheck() {
        if ((block.timestamp > s_electionInfo.endTime) || s_electionEnded)
            revert ElectionEnded();
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function initialize(
        ElectionInfo memory _electionInfo,
        Candidate[] memory _candidates,
        uint256 _resultType,
        uint256 _electionId,
        address _ballot,
        address _owner,
        address _resultCalculator
    ) external initializer {
        s_electionInfo = _electionInfo;
        uint256 _totalCandidates = _candidates.length;

        if (_totalCandidates < 2) revert InvalidCandidatesLength();

        for (uint256 i = 0; i < _totalCandidates; i++) {
            s_candidates.push(
                Candidate(i, _candidates[i].name, _candidates[i].description)
            );
        }
        s_resultType = _resultType;
        s_electionId = _electionId;
        s_owner = _owner;
        s_factoryContract = msg.sender;
        ballot = IBallot(_ballot);
        resultCalculator = IResultCalculator(_resultCalculator);
    }

    function userVote(
        uint256[] memory voteArr
    ) external electionInactiveCheck electionEndedCheck {
        if (s_userVoted[msg.sender]) revert AlreadyVoted();
        if (s_ballotInitialized == false) {
            ballot.init(s_candidates.length); // #PC - 1. Iballot contract, communicating with Ballot contract
            s_ballotInitialized = true;
        }

        emit CastVote(msg.sender);

        ballot.vote(voteArr); // #PC - 1
        s_userVoted[msg.sender] = true;
        s_totalVotes++;
    }

    /** Cross Chain Voting**/

    // function ccipVote(
    //     // #PC - 2. ccipVote, check this out
    //     address user,
    //     uint256[] memory _voteArr
    // ) external electionInactive {
    //     if (s_userVoted[user]) revert AlreadyVoted();
    //     if (s_ballotInitialized == false) {
    //         ballot.init(s_candidates.length);
    //         s_ballotInitialized = true;
    //     }
    //     if (msg.sender != s_factoryContract) revert NotOwner();
    //     s_userVoted[user] = true;
    //     ballot.vote(_voteArr);
    //     s_totalVotes++;
    // }

    function addCandidate(
        string calldata _name,
        string calldata _description
    ) external onlyOwner electionStartedCheck electionEndedCheck {
        emit AddCandidate(_name, _description);

        Candidate memory newCandidate = Candidate(
            s_candidates.length,
            _name,
            _description
        );
        s_candidates.push(newCandidate);
    }

    function removeCandidate(
        uint256 _id
    ) external onlyOwner electionStartedCheck electionEndedCheck {
        uint256 totalCandidates = s_candidates.length;

        if (_id >= totalCandidates) revert InvalidCandidateID();
        if (totalCandidates <= 2) revert InvalidCandidatesLength();

        emit RemoveCandidate(_id);

        for (uint256 i = _id; i < totalCandidates - 1; i++) {
            s_candidates[i] = s_candidates[i + 1];
            s_candidates[i].candidateID = i;
        }

        s_candidates.pop();
    }

    function endElection() external onlyOwner {
        emit EndElection();
        _calculateResult();
        _endElection();
    }

    function calculateFinalResult() external electionEndedCheck {
        if (s_resultsDeclared) revert ResultsHaveAlreadyBeenDeclared(s_winners);

        emit CalculateFinalResult();

        _calculateResult();
    }

    ///////////////////////////////////
    // Private & Internal Functions ///
    ///////////////////////////////////

    function _getTotalVotes() internal view returns (bytes memory) {
        //Checks
        if (s_candidates.length > s_totalVotes)
            revert TotalVotesExceedNumberOfCandidates(
                s_candidates.length,
                s_totalVotes
            );

        bytes memory payload = abi.encodeWithSignature("getVotes()"); //#PC why bytes?

        (bool success, bytes memory totalVotes) = address(ballot).staticcall(
            payload
        );
        if (!success) revert VotesUnavailable();

        return totalVotes;
    }

    function _calculateResult() internal {
        bytes memory totalVotes = _getTotalVotes();
        uint256[] memory _winners = resultCalculator.getResults(
            totalVotes,
            s_resultType
        );
        s_winners = _winners;
        s_resultsDeclared = true;
    }

    function _endElection() internal {
        s_electionEnded = true;
        _calculateResult();
    }

    ////////////////////////////////////////
    // Public & External View Functions  ///
    ////////////////////////////////////////

    function getElectionStatus() external view returns (bool) {
        return s_electionEnded;
    }

    function getElectionWinners() external view returns (uint256[] memory) {
        return s_winners;
    }

    function getCandidateList() external view returns (Candidate[] memory) {
        return s_candidates;
    }

    function getWinners() external view returns (uint256[] memory) {
        return s_winners;
    }
}
