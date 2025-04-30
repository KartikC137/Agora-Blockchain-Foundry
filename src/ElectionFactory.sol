// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Election} from "./Election.sol";
import {BallotGenerator} from "./ballots/BallotGenerator.sol";
import {ResultCalculator} from "./resultCalculators/ResultCalculator.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Election Factory Contract
 * @author
 *
 * This Contract Handles Creation and Deletion of Elections.
 *
 * @notice
 * 1. Cross - chain voting is not yet implemented
 * 2. When Elections are deleted, it is removed from the list of elections,
 *      but The Election Associated with Each User is not deleted, as it is
 *      very gas inefficient to do so.
 *
 */

contract ElectionFactory {
    //////////////////
    // Errors      ///
    //////////////////

    error NotOwnerOrInvalidElectionID(address owner, uint256 electionID);
    error FactoryOwnerRestricted();
    error InvalidCandidatesLength(uint256 candidateLength);

    ////////////////////////
    // State Variables   ///
    ////////////////////////

    uint256 public s_electionCount = 0;

    address public s_factoryOwner;
    address private immutable i_resultCalculator;
    address private immutable i_electionGenerator;

    address[] public s_openBasedElections;

    mapping(uint256 electionId => address owner) private s_electionOwner;
    mapping(address owner => address[] electionAddresses)
        private s_userElections;

    BallotGenerator private immutable i_ballotGenerator;

    //////////////
    // Events  ///
    //////////////

    event ElectionCreated(
        address indexed creator,
        Election.ElectionInfo indexed electionInfo,
        Election.Candidate[] indexed candidates
    );

    event ElectionDeleted(
        uint256 indexed electionInfo,
        address indexed deletedBy
    );

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != s_factoryOwner) revert FactoryOwnerRestricted();
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
    ) external returns (address) {
        if (_candidates.length < 2)
            revert InvalidCandidatesLength(_candidates.length);

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

        emit ElectionCreated(msg.sender, _electionInfo, _candidates);

        s_electionOwner[s_electionCount] = msg.sender;
        s_openBasedElections.push(electionAddress);
        s_userElections[msg.sender].push(electionAddress);
        s_electionCount++;

        return electionAddress;
    }

    function deleteElection(uint256 _electionId) external {
        if (s_electionOwner[_electionId] != msg.sender)
            revert NotOwnerOrInvalidElectionID(
                s_electionOwner[_electionId],
                _electionId
            );

        uint256 lastIndex = s_openBasedElections.length - 1;
        if (_electionId != lastIndex) {
            s_openBasedElections[_electionId] = s_openBasedElections[lastIndex];
            s_electionOwner[_electionId] = s_electionOwner[lastIndex];
        }

        emit ElectionDeleted(_electionId, msg.sender);
        s_openBasedElections.pop();
        delete s_electionOwner[lastIndex];
        s_electionCount--;
    }

    //////////////////////////////////////////////////
    // Public & External Functions View Functions  ///
    //////////////////////////////////////////////////

    function getElectionCount() external view returns (uint256) {
        return s_electionCount;
    }

    function getFactoryOwner() external view returns (address) {
        return s_factoryOwner;
    }

    function getElectionOwner(
        uint256 electionId
    ) external view returns (address) {
        return s_electionOwner[electionId];
    }

    function getElectionAddress(
        uint256 electionId
    ) external view returns (address) {
        return s_openBasedElections[electionId];
    }

    function getOpenElections() external view returns (address[] memory) {
        return s_openBasedElections;
    }

    function getUserElections(
        address user
    ) external view returns (address[] memory) {
        return s_userElections[user];
    }
}
