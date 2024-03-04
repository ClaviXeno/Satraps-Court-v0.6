// SPDX-License-Identifier: GNU LGPLv3
pragma solidity ^0.8.18;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IStatementMinter {
    function mint(uint256, string memory) external;
}

interface IDecreeMinter {
    function mint(uint256, string memory) external;
}

contract SatrapsCourt is AccessControl {
    /********************************************************/
    /************************ Errors ************************/
    /********************************************************/

    error SatrapsCourt__OnlyChairman();
    error SatrapsCourt__CollectionExists();
    error SatrapsCourt__CollectionNotExists();
    error SatrapsCourt__StartTimeError();
    error SatrapsCourt__EndTimeError();
    error SatrapsCourt__SessionStateError(string reason);
    error SatrapsCourt__VoteOptionsNotSet();
    error SatrapsCourt__VoteOptionNotExists();
    error SatrapsCourt__VoteOptionRemoved();
    error SatrapsCourt__NoVotingPower(string reason);
    error SatrapsCourt__ZeroAddress();
    error SatrapsCourt__AlreadyVoted();

    /********************************************************/
    /************************ Types *************************/
    /********************************************************/
    enum SessionState {
        OPEN,
        IN_PROGRESS,
        ENDED
    }

    /********************************************************/
    /******************* State Variables ********************/
    /********************************************************/
    uint256 public currentSessionId;
    address public chairman;
    address public statementMinter;
    address public decreeMinter;
    bool private _isCallInProgress;
    bool private isStatement;
    bytes32 public constant OFFICER = keccak256("OFFICER");

    mapping(uint256 => SessionInfo) private sessions;
    mapping(uint256 => VoteOptionInfo[]) private sessionToVoteOptionsInfo;
    mapping(uint256 => WinningVoteOption) private sessionToWinningVoteOption;
    mapping(address => CollectionInfo) private collectionToVotingInfo;
    mapping(address => Voter) private voters;
    // staked tokensId of collection to owner
    mapping(address => mapping(uint => address)) private collectionTokenIdOwner;
    mapping(address => mapping(address => uint256[]))
        private ownerToCollectionIdssStaked;

    //  session to voter vote status
    mapping(uint256 => mapping(address => bool))
        private sessionIdToVoterVotedStatus;

    address[] private acceptedCollections;

    /********************************************************/
    /*********************** Structs ************************/
    /********************************************************/
    struct CollectionInfo {
        uint256 indexInCollectionsArray;
        uint256 votePower;
        bool isAccpetable; // checks if the collection is accpetable for voting
    }

    struct VoteOptionInfo {
        uint256 optionId;
        uint256 optionVotes;
        string optionName;
        bool isActive;
    }
    struct WinningVoteOption {
        uint256 optionId;
        uint256 optionVotes;
        string optionName;
        bool isTie;
    }
    struct SessionInfo {
        uint256 voteOptionsCount;
        uint256 sessionStartTime;
        uint256 sessionEndTime;
        uint256 totalVotes;
        SessionState state;
        string sessionTitle;
        bool isStatement;
    }

    struct Voter {
        uint256 votePower;
        address delegate; // person delegated to
    }
    /********************************************************/
    /************************ Events ************************/
    /********************************************************/

    event AddedCollection(address indexed collection);
    event RemovedCollection(address indexed collection);
    event ChairmainChanged(address chairman);
    event VoteOptionsAdded(uint256 indexed sessionId, uint256 voteOptionsCount);
    event VoteOptionsRemoved(uint256 indexed sessionId, uint256 voteOptionId);
    event VotingSessionFinalized(uint256 indexed sessionId);
    event VotingSessionSkipped(uint256 indexed sessionId);
    event VoteCasted(
        uint256 indexed sessionId,
        address indexed voter,
        uint256 indexed voteOptionId
    );

    event TakeBackVotePower(
        address indexed delegator,
        address indexed delegatee,
        uint256 votePower
    );
    event DelegateVotePower(
        address indexed delegator,
        address indexed delegatee,
        uint256 votePower
    );
    event VotingSessionAdded(
        uint256 indexed sessionId,
        uint256 startTime,
        uint256 endTime,
        string sessionTitle,
        bool isStatement
    );

    /********************************************************/
    /*********************** Modifier ***********************/
    /********************************************************/
    modifier onlyChairman() {
        if (msg.sender != chairman) revert SatrapsCourt__OnlyChairman();

        _;
    }

    modifier nonReentrant() {
        require(!_isCallInProgress, "callInProgress");
        _isCallInProgress = true;

        _;
        _isCallInProgress = false;
    }

    constructor(address _statementMinter, address _decreeMinter) {
        chairman = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        statementMinter = _statementMinter;
        decreeMinter = _decreeMinter;
    }

    /********************************************************/
    /****************** Chairman Functions ******************/
    /********************************************************/
    function changeChairman(address newChairman) external onlyChairman {
        chairman = newChairman;
        emit ChairmainChanged(chairman);
    }

    function updateStatementMinter(
        address newStatementMinter
    ) external onlyChairman {
        statementMinter = newStatementMinter;
    }

    function updateDecreeMinter(address newDecreeMinter) external onlyChairman {
        decreeMinter = newDecreeMinter;
    }

    /**
     * @dev adds new collection to staking and voting
     */
    function addCollection(
        address _collection,
        uint256 _votePower
    ) external onlyChairman {
        CollectionInfo memory _collectionInfo = collectionToVotingInfo[
            _collection
        ];

        if (_collectionInfo.isAccpetable)
            revert SatrapsCourt__CollectionExists();
        uint256 lastIndex = acceptedCollections.length;

        acceptedCollections.push(_collection);

        collectionToVotingInfo[_collection] = CollectionInfo({
            indexInCollectionsArray: lastIndex,
            votePower: _votePower,
            isAccpetable: true
        });

        emit AddedCollection(_collection);
    }

    /**
     * @dev disable collection from staking and voting
     */
    function removeCollection(address _collection) external onlyChairman {
        CollectionInfo memory _collectionInfo = collectionToVotingInfo[
            _collection
        ];
        if (!_collectionInfo.isAccpetable)
            revert SatrapsCourt__CollectionNotExists();

        delete collectionToVotingInfo[_collection];
        delete acceptedCollections[_collectionInfo.indexInCollectionsArray];

        emit RemovedCollection(_collection);
    }

    function skipVotingSession() external onlyChairman {
        currentSessionId++;
        emit VotingSessionSkipped(currentSessionId - 1);
    }

    /**
     * @dev adds voting options to current session if it is not in progress
     * @param _optionsInfo is voting options.
     */
    function addVotingOptions(
        string[] memory _optionsInfo
    ) external onlyChairman {
        SessionInfo memory currentSession = sessions[currentSessionId];

        if (currentSession.state != SessionState.OPEN)
            revert SatrapsCourt__SessionStateError("Session in progress");

        uint256 lastOptionIndex = currentSession.voteOptionsCount;

        for (uint256 index = 0; index < _optionsInfo.length; index++) {
            sessionToVoteOptionsInfo[currentSessionId].push(
                VoteOptionInfo({
                    optionId: lastOptionIndex,
                    optionName: _optionsInfo[index],
                    optionVotes: 0, // default votes will be zero when a new session is created
                    isActive: true // set voting option to active
                })
            );

            lastOptionIndex++;
        }

        currentSession.voteOptionsCount = lastOptionIndex;

        sessions[currentSessionId] = currentSession;

        emit VoteOptionsAdded(currentSessionId, lastOptionIndex);
    }

    /**
     * @dev Removes voting option from current session if it is not in progress
     * @param _voteOptionId is voting optionId to remove.
     */
    function removeVoteOption(uint256 _voteOptionId) external onlyChairman {
        SessionInfo memory currentSession = sessions[currentSessionId];
        if (_voteOptionId > currentSession.voteOptionsCount)
            revert SatrapsCourt__VoteOptionNotExists();

        if (currentSession.state != SessionState.OPEN)
            revert SatrapsCourt__SessionStateError("session is in progress");

        VoteOptionInfo memory sessionVoteOptions = sessionToVoteOptionsInfo[
            currentSessionId
        ][_voteOptionId];
        if (!sessionVoteOptions.isActive)
            revert SatrapsCourt__VoteOptionRemoved();
        delete sessionToVoteOptionsInfo[currentSessionId][_voteOptionId];
        emit VoteOptionsRemoved(currentSessionId, _voteOptionId);
    }

    /**
     * @dev starts a new session if current session is not in progress
     * @param _startTime is session start time
     * @param _endTime is session end time
     * @param _sessionTitle is session title
     */
    function startVotingSession(
        uint256 _startTime,
        uint256 _endTime,
        string memory _sessionTitle,
        bool _isStatement // chairman input (newly added)
    ) external onlyChairman {
        if (_startTime < block.timestamp) revert SatrapsCourt__StartTimeError();
        if (_endTime < _startTime) revert SatrapsCourt__EndTimeError();

        SessionInfo memory currentSession = sessions[currentSessionId];
        if (currentSession.state != SessionState.OPEN)
            revert SatrapsCourt__SessionStateError(
                "Session is already in progress"
            );

        if (currentSession.voteOptionsCount == 0)
            revert SatrapsCourt__VoteOptionsNotSet();

        currentSession.sessionStartTime = _startTime;
        currentSession.sessionEndTime = _endTime;
        currentSession.sessionTitle = _sessionTitle;
        currentSession.totalVotes = 0;
        currentSession.state = SessionState.IN_PROGRESS;
        currentSession.isStatement = _isStatement;

        // update the sessions state variable
        sessions[currentSessionId] = currentSession;

        emit VotingSessionAdded(
            currentSessionId,
            _startTime,
            _endTime,
            _sessionTitle,
            _isStatement
        );
    }

    function finalizeCurrentVotingSession() external onlyChairman {
        SessionInfo memory session = sessions[currentSessionId];

        VoteOptionInfo[] memory sessionVoteOptions = sessionToVoteOptionsInfo[
            currentSessionId
        ];

        if (session.sessionEndTime > block.timestamp)
            revert SatrapsCourt__SessionStateError("Session is in progress");

        sessions[currentSessionId].state = SessionState.ENDED;
        uint lastSessionId = currentSessionId;
        currentSessionId++;

        // if not voting the session is tie
        if (session.totalVotes == 0) {
            sessionToWinningVoteOption[lastSessionId] = WinningVoteOption({
                optionId: 0,
                optionVotes: 0,
                optionName: "",
                isTie: true
            });
        } else {
            uint256 winningVotes = 0;
            uint256 winningOptionId = 0;
            string memory winningOptionName = "";
            bool isTie = false;

            for (uint256 i = 0; i < session.voteOptionsCount; i++) {
                uint256 currentOptionVotes = sessionVoteOptions[i].optionVotes;

                if (sessionVoteOptions[i].optionVotes > winningVotes) {
                    winningVotes = currentOptionVotes;
                    winningOptionId = sessionVoteOptions[i].optionId;
                    isTie = false; // Reset tie flag if a new winner is found
                    winningOptionName = sessionVoteOptions[i].optionName;
                } else if (currentOptionVotes == winningVotes) {
                    isTie = true; // Set tie flag if there is a tie
                }
            }

            if (isTie) {
                // Handle tie scenario

                sessionToWinningVoteOption[lastSessionId] = WinningVoteOption({
                    optionId: winningOptionId,
                    optionVotes: 0,
                    optionName: "",
                    isTie: true
                });
            } else {
                // Update the winning vote option for the session
                sessionToWinningVoteOption[lastSessionId] = WinningVoteOption({
                    optionId: 0,
                    optionVotes: winningVotes,
                    optionName: winningOptionName,
                    isTie: false
                });
            }
        }

        emit VotingSessionFinalized(lastSessionId);
    }

    /********************************************************/
    /******************* Mint Functions *********************/
    /********************************************************/
    /**
     * @dev OnlyRole is a modifier by thirdweb's permissions extension, it gives an array of wallet addresses permission to call the mint function
     */
    function mintStatement(
        uint256 sessionId,
        string memory uri
    ) external onlyRole(OFFICER) {
        SessionInfo memory session = sessions[sessionId];

        require(session.state == SessionState.ENDED, "Session not finalized");
        require(
            session.isStatement,
            "Statement not allowed for decree sessions."
        );

        IStatementMinter(statementMinter).mint(sessionId, uri);
    }

    function mintDecree(
        uint256 sessionId,
        string memory uri
    ) external onlyChairman {
        SessionInfo memory session = sessions[sessionId];

        require(session.state == SessionState.ENDED, "Session not finalized");
        require(
            !session.isStatement,
            "Decree not allowed for statement sessions."
        );

        IDecreeMinter(decreeMinter).mint(sessionId, uri);
    }

    /********************************************************/
    /******************* Public Functions *******************/
    /********************************************************/

    function delegateVotePower(address delegateeAddress) external {
        Voter memory _voter = voters[msg.sender];
        if (_voter.votePower == 0) revert SatrapsCourt__NoVotingPower("");

        if (delegateeAddress == address(0)) revert SatrapsCourt__ZeroAddress();

        if (sessionIdToVoterVotedStatus[currentSessionId][msg.sender])
            revert SatrapsCourt__AlreadyVoted();

        /**
         * @notice Caution: delegator will lose the chance to vote for the session if the delegatee is already voted before delegation
         */
        voters[msg.sender].delegate = delegateeAddress;
        voters[delegateeAddress].votePower += _voter.votePower;

        emit DelegateVotePower(
            msg.sender,
            delegateeAddress,
            voters[msg.sender].votePower
        );
    }

    function revokeDelegateVotePower() external {
        Voter memory _voter = voters[msg.sender];
        if (_voter.delegate == address(0)) revert SatrapsCourt__ZeroAddress();

        address delegate = _voter.delegate;
        if (sessionIdToVoterVotedStatus[currentSessionId][delegate]) {
            sessionIdToVoterVotedStatus[currentSessionId][msg.sender] = true;
        }

        _voter.delegate = address(0);
        voters[delegate].votePower -= _voter.votePower;

        emit TakeBackVotePower(msg.sender, delegate, _voter.votePower);
    }

    /**
     * @dev a user can call castVote if they have NFTs staked
     */
    function castVote(uint256 _voteOptionId) external {
        SessionInfo memory session = sessions[currentSessionId];
        VoteOptionInfo[] memory _optionsInfo = sessionToVoteOptionsInfo[
            currentSessionId
        ];
        if (session.state != SessionState.IN_PROGRESS)
            revert SatrapsCourt__StartTimeError();
        if (block.timestamp > session.sessionEndTime)
            revert SatrapsCourt__EndTimeError();

        Voter memory _voter = voters[msg.sender];

        if (_voter.votePower == 0) revert SatrapsCourt__NoVotingPower("");

        if (sessionIdToVoterVotedStatus[currentSessionId][msg.sender])
            revert SatrapsCourt__AlreadyVoted();

        sessionIdToVoterVotedStatus[currentSessionId][msg.sender] = true;

        if (
            _voteOptionId > session.voteOptionsCount ||
            !_optionsInfo[_voteOptionId].isActive
        ) revert SatrapsCourt__VoteOptionNotExists();

        if (_voter.delegate != address(0))
            revert SatrapsCourt__NoVotingPower("Can't vote: delegated nft");

        sessionToVoteOptionsInfo[currentSessionId][_voteOptionId]
            .optionVotes += _voter.votePower;

        session.totalVotes += _voter.votePower;
        sessions[currentSessionId] = session;

        emit VoteCasted(currentSessionId, msg.sender, _voteOptionId);
    }

    /**
     * @dev function to stake the tokenIds for given collection to get vote power
     */
    function stakeNFTs(
        address _collection,
        uint256[] memory _tokenIds
    ) external {
        CollectionInfo memory _collectionInfo = collectionToVotingInfo[
            _collection
        ];

        Voter memory _voter = voters[msg.sender];

        if (!_collectionInfo.isAccpetable)
            revert SatrapsCourt__CollectionNotExists();

        if (_voter.delegate != address(0))
            revert SatrapsCourt__NoVotingPower("delegated vote power");

        mapping(uint => address)
            storage tokenIdToOwner = collectionTokenIdOwner[_collection];

        uint256[] storage tokenIdsStaked = ownerToCollectionIdssStaked[
            msg.sender
        ][_collection];

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                IERC721(_collection).ownerOf(tokenId) == msg.sender,
                "caller is not the owner"
            );

            IERC721(_collection).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );
            _voter.votePower += _collectionInfo.votePower;

            tokenIdToOwner[tokenId] = msg.sender;
            tokenIdsStaked.push(tokenId);
        }

        voters[msg.sender] = _voter;
        ownerToCollectionIdssStaked[msg.sender][_collection] = tokenIdsStaked;
    }

    /**
     * @dev function to unstake the all tokenIds from given collection
     */
    function unstakeNFTs(address _collection) external nonReentrant {
        SessionInfo memory currentSession = sessions[currentSessionId];
        Voter memory _voter = voters[msg.sender];

        // if last session is ended and next session is not yet started a user can unstake NFTs
        if (currentSession.state != SessionState.OPEN)
            revert SatrapsCourt__SessionStateError("Session Not Ended");

        uint256[] memory _tokenIds = ownerToCollectionIdssStaked[msg.sender][
            _collection
        ];
        delete ownerToCollectionIdssStaked[msg.sender][_collection];

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            _unstakeNFT(_collection, _voter.delegate, msg.sender, tokenId);
        }
    }

    /**
     * @dev private function to unstake the tokenId from given collection
     */
    function _unstakeNFT(
        address _collection,
        address _delegate,
        address _caller,
        uint256 _tokenId
    ) private {
        CollectionInfo memory _collectionInfo = collectionToVotingInfo[
            _collection
        ];
        mapping(uint => address)
            storage tokenIdToOwner = collectionTokenIdOwner[_collection];

        require(tokenIdToOwner[_tokenId] == _caller, "only owner");
        delete tokenIdToOwner[_tokenId];
        IERC721(_collection).transferFrom(address(this), _caller, _tokenId);

        if (_delegate != address(0)) {
            voters[_delegate].votePower -= _collectionInfo.votePower;
            return;
        }
        voters[_caller].votePower -= _collectionInfo.votePower;
    }

    /********************************************************/
    /******************** View Functions ********************/
    /********************************************************/

    function getVoteOptionsForSessionId()
        external
        view
        returns (VoteOptionInfo[] memory)
    {
        return sessionToVoteOptionsInfo[currentSessionId];
    }

    function getVoterVotedStatus(address _voter) external view returns (bool) {
        return sessionIdToVoterVotedStatus[currentSessionId][_voter];
    }

    function getSessionInfoById(
        uint256 _sessionId
    ) external view returns (SessionInfo memory) {
        if (_sessionId > currentSessionId)
            revert SatrapsCourt__SessionStateError("Session not started");
        return sessions[_sessionId];
    }

    function getCollectionToVotingInfo(
        address _collection
    ) external view returns (CollectionInfo memory) {
        return collectionToVotingInfo[_collection];
    }

    function getStakedTokens(
        address _owner,
        address _collection
    ) external view returns (uint256[] memory tokenIds) {
        tokenIds = ownerToCollectionIdssStaked[_owner][_collection];
    }

    function getVoterInfo(address _voter) external view returns (Voter memory) {
        return voters[_voter];
    }

    function getVoteOptions(
        uint256 _sessionId
    ) external view returns (VoteOptionInfo[] memory) {
        if (_sessionId > currentSessionId)
            revert SatrapsCourt__SessionStateError("Session not started");
        return sessionToVoteOptionsInfo[_sessionId];
    }

    function getWinningOptionForSession(
        uint256 _sessionId
    ) external view returns (WinningVoteOption memory) {
        if (sessions[_sessionId].state != SessionState.ENDED)
            revert SatrapsCourt__SessionStateError("Session not ended");
        return sessionToWinningVoteOption[_sessionId];
    }

    function getAcceptedCollections() external view returns (address[] memory) {
        address[] memory collections = new address[](
            acceptedCollections.length
        );

        uint256 lastIndex = 0;

        for (uint256 i = 0; i < acceptedCollections.length; i++) {
            address currentCollection = acceptedCollections[i];
            if (collectionToVotingInfo[currentCollection].isAccpetable) {
                collections[lastIndex] = currentCollection;
                lastIndex++;
            }
        }

        return collections;
    }

    /********************************************************/
    /******************* Notes for future *******************/
    /********************************************************/

    //For future upgrades of court, deploy the new verison of court with sessionId starting from [currentSessionId + 1] of the last implementation.
    //hypothetical: for data retrieval, future upgrades can source historical session data from the older smart contract. (if _sessionid < newImplementationStartingSessionId, then call old implementation's getSessionInfoById function).
}
