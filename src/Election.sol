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
 * @author
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

    error OwnerPermissioned();
    error AlreadyVoted();
    error GetVotes();
    error ElectionIncomplete();
    error ElectionInactive();
    error InvalidCandidateID();

    ////////////////////////////
    // Types Declarations    ///
    ////////////////////////////

    struct ElectionInfo {
        uint256 startTime;
        uint256 endTime;
        string name;
        string description;
        // Election type: 0 for invite based 1 for open
    }

    struct Candidate {
        uint256 candidateID; // remove candidateId its not needed
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

    bool public s_resultsDeclared;
    bool private s_ballotInitialized;

    //////////////
    // Events  ///
    //////////////

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != s_owner) revert OwnerPermissioned();
        _;
    }

    modifier electionInactive() {
        if (
            block.timestamp < s_electionInfo.startTime ||
            block.timestamp > s_electionInfo.endTime
        ) revert ElectionInactive();
        _;
    }

    modifier electionStarted() {
        if (block.timestamp > s_electionInfo.startTime)
            revert ElectionInactive();
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function initialize(
        // #PC - Why isnt it constructor? also checkout import {Initializable}
        ElectionInfo memory _electionInfo,
        Candidate[] memory _candidates,
        uint256 _resultType,
        uint256 _electionId,
        address _ballot,
        address _owner,
        address _resultCalculator
    ) external initializer {
        s_electionInfo = _electionInfo;
        for (uint256 i = 0; i < _candidates.length; i++) {
            // add _candidates to s_candidates array
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

    function userVote(uint256[] memory voteArr) external electionInactive {
        if (s_userVoted[msg.sender]) revert AlreadyVoted();
        if (s_ballotInitialized == false) {
            ballot.init(s_candidates.length); // #PC - 1. Iballot contract, communicating with Ballot contract
            s_ballotInitialized = true;
        }
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
    //     if (msg.sender != s_factoryContract) revert OwnerPermissioned();
    //     s_userVoted[user] = true;
    //     ballot.vote(_voteArr);
    //     s_totalVotes++;
    // }

    function addCandidate(
        // #PC - 3 why is a candidate already pushed when initialized
        string calldata _name,
        string calldata _description
    ) external onlyOwner electionStarted {
        Candidate memory newCandidate = Candidate(
            s_candidates.length,
            _name,
            _description
        );
        s_candidates.push(newCandidate);
    }

    function removeCandidate(uint256 _id) external onlyOwner electionStarted {
        if (_id >= s_candidates.length) revert InvalidCandidateID(); // #PC better use try catch to trigger this error during all kind of exceptions.
        s_candidates[_id] = s_candidates[s_candidates.length - 1]; // Replace with last element. #PC 4 ISSUE: Changes order of s_candidates. Solution add bool isActive to the candidate struct and not actually delete the user
        s_candidates.pop();
    }

    //////////////////////////////////////////////////
    // Public & External Functions View Functions  ///
    //////////////////////////////////////////////////

    function getCandidateList() external view returns (Candidate[] memory) {
        return s_candidates;
    }

    function getResult() external {
        if (block.timestamp < s_electionInfo.endTime)
            revert ElectionIncomplete();
        bytes memory payload = abi.encodeWithSignature("getVotes()");

        (bool success, bytes memory allVotes) = address(ballot).staticcall(
            payload
        ); // #PC - 5. staticcall, check this out
        if (!success) revert GetVotes();

        uint256[] memory _winners = resultCalculator.getResults(
            allVotes,
            s_resultType
        );
        s_winners = _winners;
        s_resultsDeclared = true;
    }

    function getWinners() external view returns (uint256[] memory) {
        return s_winners;
    }
}
