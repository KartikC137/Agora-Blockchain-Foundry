// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Election} from "./Election.sol";
import {BallotGenerator} from "./ballots/BallotGenerator.sol";
import {ResultCalculator} from "./resultCalculators/ResultCalculator.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Election Contract
 * @author
 *
 * This Contract Handles the Elections.
 *
 * @notice Cross - chain voting is not yet implemented
 */

contract ElectionFactory {
    //////////////////
    // Errors      ///
    //////////////////

    error OnlyOwner();
    error OwnerRestricted();
    error InvalidCandidatesLength();

    ////////////////////////
    // State Variables   ///
    ////////////////////////

    uint256 public s_electionCount;

    address public s_factoryOwner;
    address private immutable i_resultCalculator;
    address private immutable i_electionGenerator;

    address[] public s_openBasedElections;

    mapping(uint256 electionId => address owner) private s_electionOwner;
    mapping(address owner => address[] electionAddresses)
        private s_userElection;

    BallotGenerator private immutable i_ballotGenerator;

    //////////////
    // Events  ///
    //////////////

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != s_factoryOwner) revert OwnerRestricted();
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////

    constructor() {
        s_factoryOwner = msg.sender;
        i_electionGenerator = address(new Election());
        i_ballotGenerator = new BallotGenerator();
        i_resultCalculator = address(new ResultCalculator());
    }

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function createElection(
        Election.ElectionInfo memory _electionInfo,
        Election.Candidate[] memory _candidates,
        uint256 _ballotType,
        uint256 _resultType
    ) external {
        if (_candidates.length < 2) revert InvalidCandidatesLength();

        address electionAddress = Clones.clone(i_electionGenerator);
        address _ballot = i_ballotGenerator.generateBallot(
            _ballotType,
            electionAddress
        );

        Election election = Election(electionAddress);
        election.initialize(
            _electionInfo,
            _candidates,
            _resultType,
            s_electionCount,
            _ballot,
            msg.sender,
            i_resultCalculator
        );

        s_electionOwner[s_electionCount] = msg.sender;
        s_openBasedElections.push(electionAddress);
        s_userElection[msg.sender].push(electionAddress);
        s_electionCount++;
    }

    function deleteElection(uint256 _electionId) external {
        if (s_electionOwner[_electionId] != msg.sender) revert OnlyOwner();

        uint256 lastIndex = s_openBasedElections.length - 1;
        if (_electionId != lastIndex) {
            s_openBasedElections[_electionId] = s_openBasedElections[lastIndex];
            s_electionOwner[_electionId] = s_electionOwner[lastIndex];
        }
        s_openBasedElections.pop();
        delete s_electionOwner[lastIndex];
    }

    //////////////////////////////////////////////////
    // Public & External Functions View Functions  ///
    //////////////////////////////////////////////////

    function getOpenElections() external view returns (address[] memory) {
        return s_openBasedElections;
    }

    function getUserElections(
        address user
    ) external view returns (address[] memory) {
        return s_userElection[user];
    }
}
