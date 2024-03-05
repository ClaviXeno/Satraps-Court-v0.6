// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockERC721} from "../src/mock/mockERC721.sol";
import {SatrapsCourt} from "../src/CoreContract.sol";
import {DecreeMinter} from "../src/DecreeMinter.sol";
import {StatementMinter} from "../src/StatementMinter.sol";

contract SatrapsCourtTest is Test {
    SatrapsCourt satrapsCourt;
    DecreeMinter decreeMinter;
    StatementMinter statementMinter;
    MockERC721 collectionZero;
    MockERC721 collectionOne;

    bytes32 public constant OFFICER = keccak256("OFFICER");
    address chairman = makeAddr("chairman");
    address chairman2 = makeAddr("chairman2");
    address nonChairman = makeAddr("nonChairman");
    address userOne = makeAddr("userOne");
    address userTwo = makeAddr("userTwo");
    address officer = makeAddr("OFFICER");

    uint256 constant VOTE_POWER = 100;

    string constant collectionZeroSymbol = "CZ";
    string constant collectionZeroName = "CcollectionZeroZ";
    string constant collectionOneSymbol = "CO";
    string constant collectionOneName = "collectionOne";

    /*************************************/
    event AddedCollection(address indexed collection);
    event RemovedCollection(address indexed collection);

    function setUp() public {
        decreeMinter = new DecreeMinter(chairman);
        statementMinter = new StatementMinter(chairman);
        satrapsCourt = new SatrapsCourt(
            address(statementMinter),
            address(decreeMinter)
        );

        collectionZero = new MockERC721(
            collectionZeroName,
            collectionZeroSymbol
        );
        collectionOne = new MockERC721(collectionOneName, collectionOneSymbol);
        satrapsCourt.changeChairman(chairman);

        // grant DEFAULT ADMIN ROLE to new chairman
        satrapsCourt.grantRole(satrapsCourt.DEFAULT_ADMIN_ROLE(), chairman);
    }

    /***************************************************/

    function setupSatrapsCourtSession() private {
        string[] memory optionsInfo = new string[](2);
        optionsInfo[0] = "test opt1";
        optionsInfo[1] = "test opt1";
        vm.startPrank(chairman);

        // step 0: add collections
        satrapsCourt.addCollection(address(collectionZero), VOTE_POWER);
        satrapsCourt.addCollection(address(collectionOne), VOTE_POWER * 2);

        // step 1: add voting options
        satrapsCourt.addVotingOptions(optionsInfo);

        // step 2: create voting session
        uint256 startTime = block.timestamp + 200;
        uint256 endTime = block.timestamp + 2000;
        string memory sessionTitle = "test session";
        bool isStatement = false;
        satrapsCourt.startVotingSession(
            startTime,
            endTime,
            sessionTitle,
            isStatement
        );

        vm.stopPrank();

        //  mint a NFT for user in collection zero
        vm.prank(userOne);
        collectionZero.mint();
        vm.prank(userTwo);
        collectionZero.mint();
    }

    /***************************************************/

    function test__testCollections() public view {
        string memory collectionZeroAcutalName = collectionZero.name();

        assert(
            keccak256(bytes(collectionZeroAcutalName)) ==
                keccak256(bytes(collectionZeroName))
        );

        string memory collectionOneAcutalName = collectionOne.name();

        assert(
            keccak256(bytes(collectionOneAcutalName)) ==
                keccak256(bytes(collectionOneName))
        );
    }

    function test__changeChairman() public {
        vm.prank(chairman);
        satrapsCourt.changeChairman(chairman2);
        assert(satrapsCourt.chairman() == chairman2);
    }

    function test__addCollection() public {
        vm.expectEmit(true, false, false, false, address(satrapsCourt));
        emit AddedCollection(address(collectionOne));

        vm.prank(chairman);
        satrapsCourt.addCollection(address(collectionOne), VOTE_POWER);

        SatrapsCourt.CollectionInfo memory _collectionInfo = satrapsCourt
            .getCollectionToVotingInfo(address(collectionOne));

        assert(_collectionInfo.isAccpetable);
        assert(_collectionInfo.votePower == VOTE_POWER);
    }

    function test__removeCollection() public {
        vm.prank(chairman);
        satrapsCourt.addCollection(address(collectionOne), VOTE_POWER);

        vm.expectEmit(true, false, false, false, address(satrapsCourt));
        emit RemovedCollection(address(collectionOne));

        vm.prank(chairman);
        satrapsCourt.removeCollection(address(collectionOne));

        SatrapsCourt.CollectionInfo memory _collectionInfo = satrapsCourt
            .getCollectionToVotingInfo(address(collectionOne));

        assert(!_collectionInfo.isAccpetable);
    }

    function addOptions() internal {
        string[] memory optionsInfo = new string[](2);
        optionsInfo[0] = "test opt1";
        optionsInfo[1] = "test opt1";

        vm.prank(chairman);
        satrapsCourt.addVotingOptions(optionsInfo);
    }

    function test__addVotingOptions() public {
        string[] memory optionsInfo = new string[](2);
        optionsInfo[0] = "test opt1";
        optionsInfo[1] = "test opt1";

        addOptions();
        SatrapsCourt.VoteOptionInfo[] memory actualOptions = satrapsCourt
            .getVoteOptionsForSessionId();

        for (uint256 i = 0; i < actualOptions.length; i++) {
            assert(
                keccak256(bytes(actualOptions[i].optionName)) ==
                    keccak256(bytes(optionsInfo[i]))
            );
        }
    }

    function test__removeVoteOption() public {
        addOptions();
        uint256 optionIdToRemove = 0;

        vm.prank(chairman);
        satrapsCourt.removeVoteOption(optionIdToRemove);

        SatrapsCourt.VoteOptionInfo[] memory actualOptions = satrapsCourt
            .getVoteOptionsForSessionId();

        assert(!actualOptions[optionIdToRemove].isActive);
    }

    function test__startVotingSession() public {
        addOptions();

        uint256 startTime = block.timestamp + 200;
        uint256 endTime = block.timestamp + 2000;
        string memory sessionTitle = "test session";
        bool isStatement = false;

        vm.prank(chairman);
        satrapsCourt.startVotingSession(
            startTime,
            endTime,
            sessionTitle,
            isStatement
        );
        uint256 sessionId = satrapsCourt.currentSessionId();
        SatrapsCourt.SessionInfo memory actualSessionInfo = satrapsCourt
            .getSessionInfoById(sessionId);

        assert(actualSessionInfo.sessionStartTime == startTime);
        assert(actualSessionInfo.sessionEndTime == endTime);

        assert(
            actualSessionInfo.state == SatrapsCourt.SessionState.IN_PROGRESS
        );
    }

    function stakeNFTsFromUserOne() internal {
        uint256[] memory tokenIdsToStake = new uint256[](1);
        tokenIdsToStake[0] = 0;
        vm.startPrank(userOne);
        collectionZero.setApprovalForAll(address(satrapsCourt), true);

        satrapsCourt.stakeNFTs(address(collectionZero), tokenIdsToStake);
        vm.stopPrank();
    }

    function stakeNFTsFromUserTwo() internal {
        uint256[] memory tokenIdsToStake = new uint256[](1);
        tokenIdsToStake[0] = 1;
        vm.startPrank(userTwo);
        collectionZero.setApprovalForAll(address(satrapsCourt), true);

        satrapsCourt.stakeNFTs(address(collectionZero), tokenIdsToStake);
        vm.stopPrank();
    }

    function test__stakeNFTs() public {
        setupSatrapsCourtSession();
        stakeNFTsFromUserOne();

        uint256 expectedVotingPower = 100;
        SatrapsCourt.Voter memory _userOne = satrapsCourt.getVoterInfo(userOne);
        assert(_userOne.votePower == expectedVotingPower);
    }

    function finalizeCurrentVotingSession() internal {
        uint256 endTime = block.timestamp + 3000;
        skip(endTime);
        vm.prank(chairman);
        satrapsCourt.finalizeCurrentVotingSession();
    }

    function test__finalizeCurrentVotingSession() public {
        setupSatrapsCourtSession();
        uint256 currentSessionId = satrapsCourt.currentSessionId();

        stakeNFTsFromUserOne();
        uint256 votingOption = 0;
        vm.prank(userOne);
        satrapsCourt.castVote(votingOption);

        finalizeCurrentVotingSession();
        SatrapsCourt.SessionInfo memory session = satrapsCourt
            .getSessionInfoById(currentSessionId);

        SatrapsCourt.WinningVoteOption memory winningOption = satrapsCourt
            .getWinningOptionForSession(0);
        assert(!winningOption.isTie);
        assert(satrapsCourt.currentSessionId() == currentSessionId + 1);
        assert(session.state == SatrapsCourt.SessionState.ENDED);
    }

    function test__finalizeCurrentVotingSessionWitTie() public {
        setupSatrapsCourtSession();
        uint256 currentSessionId = satrapsCourt.currentSessionId();

        stakeNFTsFromUserOne();
        stakeNFTsFromUserTwo();
        uint256 optionOne = 0;
        uint256 optionTwo = 1;
        vm.prank(userOne);
        satrapsCourt.castVote(optionOne);

        vm.prank(userTwo);
        satrapsCourt.castVote(optionTwo);

        finalizeCurrentVotingSession();
        SatrapsCourt.SessionInfo memory session = satrapsCourt
            .getSessionInfoById(currentSessionId);

        SatrapsCourt.WinningVoteOption memory winningOption = satrapsCourt
            .getWinningOptionForSession(0);

        assert(winningOption.isTie);
        assert(satrapsCourt.currentSessionId() == currentSessionId + 1);
        assert(session.state == SatrapsCourt.SessionState.ENDED);
    }

    function test__unstakeNFTs() public {
        setupSatrapsCourtSession();

        stakeNFTsFromUserOne();
        finalizeCurrentVotingSession();

        vm.prank(userOne);
        satrapsCourt.unstakeNFTs(address(collectionZero));

        assert(collectionZero.ownerOf(0) == userOne);
    }

    function test__grantOfficerRole() public {
        address _chairman = satrapsCourt.chairman();

        vm.prank(_chairman);
        satrapsCourt.grantRole(OFFICER, officer);

        assert(satrapsCourt.hasRole(OFFICER, officer));
    }
}
