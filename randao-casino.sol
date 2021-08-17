// SPDX-License-Identifier: MIT

pragma solidity >=0.4.24 <=0.8.4;

contract Casino {
    
    struct Participant {
        uint256 betting;
        uint256 secret;
        uint [4] bettingNumber;
        bytes32 commitment;
        uint256 reward;
        bool revealed;
        bool rewarded;
    }
    
    struct Consumer {
        address consumerAddr;
        uint256 bountyPot;
    }
    
    struct Campaign {
        uint32 blockNum;
        uint96 deposit;
        uint16 commitBalkline;
        uint16 commitDeadline;
        
        uint256 random;
        bool settled;
        uint256 bountyPot;
        uint32 commitNum;
        uint32 revealsNum;
        
        mapping (address => Consumer) consumers;
        mapping (address => Participant) participants;
        mapping (bytes32 => bool) commitments;
    }
    
    uint256 public numCampaigns;
    Campaign[] public campaigns;
    address payable founder;

    
    modifier blankAddress(address n) { if (n != address(0)) revert(); _; }
    
    modifier moreThanZero(uint256 _deposit) {if (_deposit <= 0) revert(); _; }
    
    modifier notBeBlank(bytes32 _s) { if (_s == "") revert(); _; }
    
    modifier beBlank(bytes32 _s) { if (_s != "") revert(); _; }
    
    modifier beFalse(bool _t) { if (_t) revert(); _; }
    
    constructor() public payable{
        founder = payable(msg.sender);
    }
    
    event LogCampaignAdded(uint256 indexed campaignID,
                           address indexed from,
                           uint32 indexed blockNum,
                           uint96 deposit,
                           uint16 commitBalkline,
                           uint16 commitDeadline,
                           uint256 bountyPot);
                           
    modifier timeLineCheck(uint32 _blockNum, uint16 _commitBalkline, uint16 _commitDeadline) {
        if(block.number >= _blockNum) revert();
        if(_commitBalkline <= 0) revert();
        if(_commitDeadline <= 0) revert();
        if(_commitDeadline >= _commitBalkline) revert();
        if(block.number >= _blockNum - _commitBalkline) revert();
        
        _;
    }
    
    /*
     struct Campaign {
        uint32 blockNum;
        uint96 deposit;
        uint16 commitBalkline;
        uint16 commitDeadline;
        
        uint256 random;
        bool settled;
        uint256 bountyPot;
        uint32 commitNum;
        uint32 revealsNum;
        
        mapping (address => Consumer) consumers;
        mapping (address => Participant) participants;
        mapping (bytes32 => bool) commitments;
    }
    
    */
    
    function newCampaignAuto(
        uint96 _deposit
    ) payable external moreThanZero(_deposit) returns(uint256 _campaignID){
        _campaignID = campaigns.length;
        campaigns.push();
        Campaign storage c = campaigns[_campaignID];
        numCampaigns++;
        
        c.blockNum = uint32(block.number);
        c.deposit = _deposit;
        c.commitBalkline = uint16(uint(keccak256(abi.encodePacked(block.number, block.difficulty, block.gaslimit, block.timestamp)))) % 200 + 200;
        c.commitDeadline = uint16(uint(keccak256(abi.encodePacked(block.number, block.difficulty, block.gaslimit, block.timestamp)))) % 200;
        c.bountyPot = msg.value;
        c.consumers[msg.sender] = Consumer(msg.sender, msg.value); 
        
            
        emit LogCampaignAdded(_campaignID, msg.sender, c.blockNum, _deposit, c.commitBalkline, c.commitDeadline, _deposit);
        
        return _campaignID;
    }
    
    function newCampaign(
         uint32 _blockNum,
         uint96 _deposit,
         uint16 _commitBalkline,
         uint16 _commitDeadline
    ) payable
        timeLineCheck(_blockNum, _commitBalkline, _commitDeadline)
        moreThanZero(_deposit) 
        external returns(uint256 _campaignID) {
            Campaign storage c = campaigns[_campaignID];
            _campaignID =  campaigns.length;
            numCampaigns++;
            
            c.blockNum = _blockNum;
            c.deposit = _deposit;
            c.commitBalkline = _commitBalkline;
            c.commitDeadline = _commitDeadline;
            c.bountyPot = msg.value;
            c.consumers[msg.sender] = Consumer(msg.sender, msg.value);
            
            emit LogCampaignAdded(_campaignID, msg.sender, _blockNum, _deposit, _commitBalkline, _commitDeadline, msg.value);
            
            return _campaignID;
    }
    
    event LogFollow(uint256 indexed CampaignId, address indexed from, uint256 bountyPot);
    
    function follow(uint256 _campaignID) external payable returns (bool) {
        Campaign storage c = campaigns[_campaignID];
        Consumer storage consumer = c.consumers[msg.sender];
        return followCampaign(_campaignID, c, consumer);
    }
    
    modifier checkFollowPhase(uint256 _blockNum, uint16 _commitDeadline) {
        if(block.number > _blockNum - _commitDeadline) revert();
        _;
    }
    
    function followCampaign(
        uint256 _campaignID,
        Campaign storage c,
        Consumer storage consumer
    ) checkFollowPhase(c.blockNum, c.commitDeadline) blankAddress(consumer.consumerAddr) internal returns(bool) {
        c.bountyPot += msg.value;
        c.consumers[msg.sender] = Consumer(msg.sender, msg.value);
        emit LogFollow(_campaignID, msg.sender, msg.value);
        
        return true;
    }
    
    event LogCommit(uint256 indexed CampaignId, address indexed from, bytes32 commitment);
    
    function commit(uint256 _campaignID, bytes32 _hs) notBeBlank(_hs) external payable {
        Campaign storage c = campaigns[_campaignID];
        commitmentCampaign(_campaignID, _hs, msg.value, c);
    }
    
    modifier checkDeposit(uint256 _deposit) { if (msg.value != _deposit) revert(); _;}
    
    modifier checkCommitPhase(uint256 _blockNum, uint16 _commitBalkline, uint16 _commitDeadline) {
        if (_blockNum < _commitBalkline || _blockNum < _commitDeadline) { 
            _; 
            
        } else {
            if (block.number < _blockNum - _commitBalkline) revert();
            if (block.number > _blockNum - _commitDeadline) revert();
        }
        _;
    }
    
    
    /*
    struct Participant {
        uint betAmount; - How many betting to win
        uint64 [] bettingNumber; - BettingNumber that is changed from hasehd Number
        bytes32 commitment; - Secret Number with hashed, when it is revealed it become nand
        uint256 reward; - reward to giveback
        bool revealed; - is it revealed?
        bool rewarded; - is it rewarded?
    }
    */
    
    function getCommitmentNumber(uint256 _campaignID) public view returns (uint [4] memory){
        return campaigns[_campaignID].participants[msg.sender].bettingNumber;
    }
    
    function commitmentCampaign(
        uint256 _campaignID,
        bytes32 _hs,
        uint256 betting,
        Campaign storage c
    ) checkDeposit(c.deposit) 
      //checkCommitPhase(c.blockNum, c.commitBalkline, c.commitDeadline)
      beBlank(c.participants[msg.sender].commitment) internal {
          if(c.commitments[_hs]) {
              revert();
          } else  {
              
              uint[4] memory arrayBettingNumber = commitmentsNumber(_hs);
              
              c.participants[msg.sender] = Participant(betting, 0, arrayBettingNumber, _hs, 0, false, false);
              c.commitNum++;
              c.commitments[_hs] = true;
              
              emit LogCommit(_campaignID, msg.sender, _hs);
          }
      }
      
      
    function bytesToUint(bytes32 b) internal pure returns (uint){
        uint number;
        for(uint i=0;i<b.length;i++){
            number = number + uint(uint8(b[i]))*(2**(8*(b.length-(i+1))));
        }
        return number;
    }
    
    function commitmentsNumber(bytes32 _hs) internal pure returns (uint[4] memory){
        bytes32 a = bytes32(bytes8(_hs >> 0));
        bytes32 b = bytes32(bytes8(_hs >> 8));
        bytes32 c = bytes32(bytes8(_hs >> 16));
        bytes32 d = bytes32(bytes8(_hs >> 32));
        
        uint[4] memory temp;
        
        temp[0] = bytesToUint(a);
        temp[1] = bytesToUint(b);
        temp[2] = bytesToUint(c);
        temp[3] = bytesToUint(d);
        
        return temp;
    }
    
    function getCommitment(uint256 _campaignID) external view returns(bytes32) {
        Campaign storage c = campaigns[_campaignID];
        Participant storage p = c.participants[msg.sender];
        return p.commitment;
    }
    
    function shaCommit(uint256 _s) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_s));
    }
    
    function reveal(uint256 _campaignID, uint256 _s) external {
        Campaign storage c = campaigns[_campaignID];
        Participant storage p = c.participants[msg.sender];
        revealCampaign(_campaignID, _s, c, p);
    }
    
    event LogReveal(uint256 indexed CampaignId, address indexed from, uint256 secret);
    
    modifier checkRevealPhase(uint256 _blockNum, uint16 _commitDeadline) {
        if (block.number <= _blockNum - _commitDeadline) revert();
        if (block.number >= _blockNum) revert();
        _;
    }
    
    modifier checkSecret(uint256 _s, bytes32 _commitment) {
        if (keccak256(abi.encodePacked(_s)) != _commitment) revert();
        _;
    }
    
    function revealCampaign(
        uint256 _campaignID,
        uint256 _s,
        Campaign storage c,
        Participant storage p
    ) checkRevealPhase(c.blockNum, c.commitDeadline)
        checkSecret(_s, p.commitment)
        beFalse(p.revealed) internal {
        p.secret= _s;
        p.revealed = true;
        c.revealsNum++;
        c.random ^= p.secret;
        emit LogReveal(_campaignID, msg.sender, _s);
    }
    
    modifier bountyPhase(uint256 _bnum){if (block.number < _bnum) revert(); _;}

    function getRandom(uint256 _campaignID) external returns (uint256) {
        Campaign storage c = campaigns[_campaignID];
        return returnRandom(c);
    }

    function returnRandom(Campaign storage c) internal bountyPhase(c.blockNum) returns (uint256) {
        if (c.revealsNum == c.commitNum) {
            c.settled = true;
            return c.random;
        }
    }
    
    function getMyBounty(uint256 _campaignID) external {
        Campaign storage c = campaigns[_campaignID];
        Participant storage p = c.participants[msg.sender];
        transferBounty(c, p);
    }

    function transferBounty(
        Campaign storage c,
        Participant storage p
        ) bountyPhase(c.blockNum)
        beFalse(p.rewarded) internal {
        if (c.revealsNum > 0) {
            if (p.revealed) {
                uint256 share = calculateShare(c);
                returnReward(share, c, p);
            }
        // Nobody reveals
        } else {
            returnReward(0, c, p);
        }
    }

    function calculateShare(Campaign storage c) internal view returns (uint256 _share) {
        // Someone does not reveal. Campaign fails.
        if (c.commitNum > c.revealsNum) {
            _share = fines(c) / c.revealsNum;
        // Campaign succeeds.
        } else {
            _share = c.bountyPot / c.revealsNum;
        }
    }

    function returnReward(
        uint256 _share,
        Campaign storage c,
        Participant storage p
    ) internal {
        p.reward = _share;
        p.rewarded = true;
        payable(msg.sender).transfer(_share + c.deposit);
    }

    function fines(Campaign storage c) internal view returns (uint256) {
        return (c.commitNum - c.revealsNum) * c.deposit;
    }

    // If the campaign fails, the consumers can get back the bounty.
    function refundBounty(uint256 _campaignID) external {
        Campaign storage c = campaigns[_campaignID];
        returnBounty(c);
    }

    modifier campaignFailed(uint32 _commitNum, uint32 _revealsNum) {
        if (_commitNum == _revealsNum && _commitNum != 0) revert();
        _;
    }

    modifier beConsumer(address _caddr) {
        if (_caddr != msg.sender) revert();
        _;
    }

    function returnBounty(Campaign storage c)
        internal
        bountyPhase(c.blockNum)
        campaignFailed(c.commitNum, c.revealsNum)
        beConsumer(c.consumers[msg.sender].consumerAddr) {
        uint256 bountypot = c.consumers[msg.sender].bountyPot;
        c.consumers[msg.sender].bountyPot = 0;
        payable(msg.sender).transfer(bountypot);
    }
    
    function kill() public {
        require(msg.sender == founder);
        selfdestruct(founder);
    }
}