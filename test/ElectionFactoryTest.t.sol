// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Some tests are incomplete

import {Test, console} from "forge-std/Test.sol";
import {ElectionFactory} from "../src/ElectionFactory.sol";
import {Election} from "../src/Election.sol";
import {DeployElectionFactory} from "../script/DeployElectionFactory.s.sol";

contract ElectionFactoryTest is Test {
    event ElectionCreated(
        address indexed creator,
        Election.ElectionInfo indexed electionInfo,
        Election.Candidate[] indexed candidates
    );

    event ElectionDeleted(
        uint256 indexed electionInfo,
        address indexed deletedBy
    );

    address[] public electionAddresses;
    address USER1 = makeAddr("user1");

    ElectionFactory electionFactory;

    Election.Candidate[] public candidates;
    Election.ElectionInfo public electionInfo =
        Election.ElectionInfo({
            startTime: 0,
            endTime: 0,
            name: "Test Election",
            description: "This is a test election"
        });

    function setUp() external {
        DeployElectionFactory deployer = new DeployElectionFactory();
        electionFactory = deployer.run();
    }

    //////////////////
    // Owner Tests ///
    //////////////////

    function testSetsTheRightFactoryOwner() public view {
        assertEq(electionFactory.s_factoryOwner(), msg.sender);
    }

    ////////////////////////////
    // Create Election Tests ///
    ////////////////////////////

    function testCreatesElectionAndUpdatesElectionsElectionOwnersUserElectionsAndElectionCount()
        public
    {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        uint256 electionCountBefore = 0;

        vm.prank(USER1);
        address election1 = electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
        electionAddresses.push(election1);

        uint256 electionCountAfter = 1;

        assertEq(
            electionFactory.getElectionAddress(electionCountBefore),
            election1
        );
        assertEq(electionFactory.getElectionOwner(electionCountBefore), USER1);
        assertEq(electionFactory.getUserElections(USER1), electionAddresses);
        assertEq(electionFactory.getElectionCount(), electionCountAfter);
    }

    function testUsersCanCreateMultipleElectionsAndUpdatesUserElections()
        public
    {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        //election 1
        vm.prank(USER1);
        address election1 = electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
        electionAddresses.push(election1);

        //election 2
        vm.prank(USER1);
        address election2 = electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
        electionAddresses.push(election2);

        assertEq(electionFactory.getUserElections(USER1), electionAddresses);
    }

    function testEmitsProperEventWhenCreated() public {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        vm.expectEmit(true, true, true, false);
        emit ElectionCreated(USER1, electionInfo, candidates);
        vm.prank(USER1);
        electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
    }

    function testRevertsIfLessThanTwoCandidates() public {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        // Only one candidate, should revert
        uint256 resultType = 0;
        uint256 ballotType = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ElectionFactory.InvalidCandidatesLength.selector,
                candidates.length
            )
        );
        electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
    }

    ////////////////////////////
    // Delete Election Tests ///
    ////////////////////////////

    function testDeletesElectionAndEmitsEventSuccessfully() public {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        vm.prank(USER1);
        electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );

        assertEq(electionFactory.getElectionCount(), 1);

        vm.expectEmit(true, true, false, false);
        emit ElectionDeleted(0, USER1);

        vm.prank(USER1);
        electionFactory.deleteElection(0);

        assertEq(electionFactory.getElectionCount(), 0);
    }

    function testRevertsIfNonOwnerTriesToDelete() public {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        vm.prank(USER1);
        electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ElectionFactory.NotOwnerOrInvalidElectionID.selector,
                msg.sender,
                1
            )
        );
        electionFactory.deleteElection(1);
    }

    function testRevertsIfInvalidIndex() public {
        candidates.push(Election.Candidate(1, "Alice", "Candidate 1"));
        candidates.push(Election.Candidate(2, "Bob", "Candidate 2"));

        uint256 resultType = 0;
        uint256 ballotType = 1;

        vm.prank(USER1);
        electionFactory.createElection(
            electionInfo,
            candidates,
            ballotType,
            resultType
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ElectionFactory.NotOwnerOrInvalidElectionID.selector,
                USER1,
                2
            )
        );
        vm.prank(USER1);
        electionFactory.deleteElection(2);
    }
}
