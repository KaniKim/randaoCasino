// SPDX-License-Identifier: MIT

pragma solidity >=0.4.24 <=0.8.7;

contract Casino {
    
    struct Participant {
        uint256 secret;
        bytes32 commitment;
        uint256 reward;
        bool revealed;
        bool rewarded;
    }
    
    struct Player {
        uint [4] bettingNumber;
        uint256 bettingAmount;
        address playerAddr;
    }
    
    struct Consumer {
        address consumerAddr;
        uint256 bountyPot;
    }
    
    struct Campaign {
        uint32 blockNum;
        uint256 deposit;
        uint16 commitBalkline;
        uint16 commitDeadline;
        
        uint256 random;
        bool settled;
        uint256 bountyPot;
        uint32 commitNum;
        uint32 revealsNum;
        
        mapping (address => Consumer) consumers;
        mapping (address => Participant) participants;
        mapping (address => Player) players;
        mapping (bytes32 => bool) commitments;
    }

    struct playerAddress {
        address[1000000] playerList;
        uint256 counter;
    }
    
    uint256 public numCampaigns;
    uint256 public maxBetting;
    uint256 public maximumPlayer;
    Campaign[] public campaigns;
    mapping(uint256 => playerAddress) internal playersMap;
    address payable founder;
    
    modifier blankAddress(address n) { if (n != address(0)) revert(); _; }
    
    modifier moreThanZero(uint256 _deposit) {if (_deposit <= 0) revert(); _; }
    
    modifier notBeBlank(bytes32 _s) { if (_s == "") revert(); _; }
    
    modifier beBlank(bytes32 _s) { if (_s != "") revert(); _; }
    
    modifier beFalse(bool _t) { if (_t) revert(); _; }
    
    constructor(uint256 _maxBetting, uint256 _maximumPlayer) public payable{
        founder = payable(msg.sender);
        maxBetting = _maxBetting;
        maximumPlayer = _maximumPlayer;
    }
    
    event LogCampaignAdded(uint256 indexed campaignID,
                           address indexed from,
                           uint32 indexed blockNum,
                           uint256 deposit,
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
    
    function newCampaignAuto() payable external 
        moreThanZero(msg.value) 
    returns(uint256 _campaignID) {
        _campaignID = campaigns.length;
        campaigns.push();
        Campaign storage c = campaigns[_campaignID];
        numCampaigns++;
         
        playersMap[_campaignID].counter = 0;
        c.deposit  = 0;
        c.blockNum = uint32(block.number) + 200;
        c.commitBalkline = uint16(uint(keccak256(abi.encodePacked(block.number, block.difficulty, block.gaslimit)))) % 200 + 200;
        c.commitDeadline = uint16(uint(keccak256(abi.encodePacked(block.number, block.difficulty, block.timestamp)))) % 200;
        c.bountyPot = msg.value;
        c.consumers[msg.sender] = Consumer(msg.sender, msg.value); 
        
        emit LogCampaignAdded(_campaignID, msg.sender, c.blockNum, 0, c.commitBalkline, c.commitDeadline, 0);
        
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
    ) 
    checkFollowPhase(c.blockNum, c.commitDeadline) 
    blankAddress(consumer.consumerAddr)
    internal returns(bool) {
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

    modifier checkMaximum(uint256 _deposit) { if (msg.value > maxBetting) revert(); _; }
    
    modifier checkCommitPhase(uint256 _blockNum, uint16 _commitBalkline, uint16 _commitDeadline) {
        if (block.number < _blockNum - _commitBalkline) revert();
        if (block.number > _blockNum - _commitDeadline) revert();
        _;
    }
    

    function getCommitmentNumber(uint256 _campaignID) public view returns (uint [4] memory){
        return campaigns[_campaignID].players[msg.sender].bettingNumber;
    }
    
    modifier checkPlayer(uint256 _campaignID) {
        address[] memory list = new address[](playersMap[_campaignID].counter);
        bool check = false;
        
        for (uint i=0; i < list.length; i++) {
            if (list[i] == msg.sender) check = true; 
        }
        
        if (!check) { revert(); _; } 
    }
    
    modifier checkBetting(uint256 betting) { if(betting > msg.sender.balance) revert(); _; }
    
    function commitmentCampaign(
        uint256 _campaignID,
        bytes32 _hs,
        uint256 betting,
        Campaign storage c
    )
    checkBetting(betting)
    checkMaximum(betting)
    checkCommitPhase(c.blockNum, c.commitBalkline, c.commitDeadline)
    beBlank(c.participants[msg.sender].commitment) internal {
          if(c.commitments[_hs]) {
              revert();
          } else  {
              
              uint[4] memory arrayBettingNumber = commitmentsNumber(_hs);
              
              c.participants[msg.sender] = Participant(0, _hs, 0, false, false);
              c.players[msg.sender] = Player(arrayBettingNumber, betting, msg.sender);
              c.commitNum++;
              c.deposit += betting;
              c.commitments[_hs] = true;
              
              playersMap[_campaignID].playerList[playersMap[_campaignID].counter] = msg.sender;
              playersMap[_campaignID].counter += 1;
              
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
        
        uint[4] memory temp;
        uint integer = bytesToUint(_hs);
        temp[0] = integer%9;
        temp[1] = integer%99;
        temp[2] = integer%999;
        temp[3] = integer%9999;
        
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
    )   
    checkRevealPhase(c.blockNum, c.commitDeadline)
    checkSecret(_s, p.commitment)
    beFalse(p.revealed) internal {
        p.secret= _s;
        p.revealed = true;
        c.revealsNum++;
        c.random = c.random ^ p.secret;
        emit LogReveal(_campaignID, msg.sender, _s);
    }
    
    modifier bountyPhase(uint256 _bnum){if (block.number < _bnum) revert(); _;}

    function getRandom(uint256 _campaignID) external returns (uint256) {
        Campaign storage c = campaigns[_campaignID];
        return returnRandom(c);
    }

    function returnRandom(Campaign storage c) internal //bountyPhase(c.blockNum) 
    returns (uint256) {
        if (c.revealsNum == c.commitNum) {
            c.settled = true;
            return c.random;
        }
    }
    
    //------------------------------------------------------------------------------------------------------------------------------
    
    function getMyBounty(uint256 _campaignID) external {
        Campaign storage c = campaigns[_campaignID];
        Participant storage p = c.participants[msg.sender];
        address[3] memory w = checkWinner(_campaignID);
        c.deposit -= transferBounty(c, p, w);
    }

    function transferBounty(
        Campaign storage c,
        Participant storage p,
        address[3] memory w
        ) 
        bountyPhase(c.blockNum)
        beFalse(p.rewarded) internal returns (uint256) {
        if (c.revealsNum > 0) {
            if (p.revealed) {
                uint256 share = 0;
                for(uint i=0; i < 3; i++) {
                    if (w[i] == msg.sender) { share = calculateShare(c, i); }
                }
                
                returnReward(share, p);
                
                return share;
            }
        // Nobody reveals
        } else {
            returnReward(0, p);
            
            return 0;
        }
    }

    function calculateShare(Campaign storage c, uint256 winner) internal view returns (uint256 _share) {
        // Someone does not reveal. Campaign fails.
        
        if (c.commitNum > c.revealsNum) {
            _share = fines(c)[winner] / c.revealsNum;
            // Campaign succeeds.
        } else {
            _share = fines(c)[winner];
        }
        
    }

    function returnReward(
        uint256 _share,
        Participant storage p
    ) internal {
        p.reward = _share;
        p.rewarded = true;
        payable(msg.sender).transfer(_share);
    }
    
    function getThisBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function fines(Campaign storage c) internal view returns (uint[4] memory) {
        uint[4] memory temp;
        
        temp[0] = c.deposit >> 1;
        temp[1] = c.deposit >> 2;
        temp[2] = c.deposit >> 2;
        temp[3] = c.deposit;
        
        return temp;
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
        beConsumer(c.consumers[msg.sender].consumerAddr) 
    {
        uint256 bountypot = c.consumers[msg.sender].bountyPot;
        c.consumers[msg.sender].bountyPot = 0;
        payable(msg.sender).transfer(bountypot);
    }
    
    
    function computeToUint(uint[4] memory bettingNumber) internal pure returns (uint256) {
        uint256 temp = bettingNumber[0] + bettingNumber[1] + bettingNumber[2] + bettingNumber[3];
        return temp;
    }
    
    
    function watchPlayer(uint256 _campaignID) public view returns (address[] memory) {
        address[] memory temp = new address[](playersMap[_campaignID].counter);
        
        for(uint256 i = 0; i < playersMap[_campaignID].counter; i++) {
            temp[i] = playersMap[_campaignID].playerList[i];
        }
        return temp;
    }
    
    function checkWinner(uint256 _campaignID) public view returns (address[3] memory) {
        
        Campaign storage c = campaigns[_campaignID];
        
        if (c.revealsNum != c.commitNum) {revert();}
        if (c.commitNum == 0) {revert();}
        
        uint256 counter = playersMap[_campaignID].counter;
        
        address[] memory playerList = watchPlayer(_campaignID);
        uint256 [] memory bettingNumberList = new uint256[](counter);
        
        for(uint i = 0; i < counter; i++) {
            bettingNumberList[i] = computeToUint(c.players[playerList[i]].bettingNumber);
        }
        
        
        //find 1st, 2nd, 3rd biggest winner
        uint256 [3] memory numberWinner;
        numberWinner[0] = 0;
        numberWinner[1] = 0;
        numberWinner[2] = 0;
        
        address [3] memory addressWinner;
        
        for(uint i = 0; i < counter; i++) {
            if (numberWinner[0] < bettingNumberList[i]) {
                
                if(numberWinner[0] <= numberWinner[1]) {
                    
                    if(numberWinner[1] <= numberWinner[2]) {
                        numberWinner[2] = numberWinner[1];
                        addressWinner[2] = addressWinner[1];
                    } 
                    numberWinner[0] = numberWinner[1];
                    addressWinner[0] = addressWinner[1];
                }
                
                numberWinner[0] = bettingNumberList[i];
                addressWinner[0] = playerList[i];
                
            } else if (numberWinner[1] < bettingNumberList[i]) {
                
                if(numberWinner[1] <= numberWinner[2]) {
                    numberWinner[2] = numberWinner[1];
                    addressWinner[2] = addressWinner[1];
                }
                
                numberWinner[1] = bettingNumberList[i];
                addressWinner[1] = playerList[i];
                
            } else if (numberWinner[2] < bettingNumberList[i]) {
                numberWinner[2] = bettingNumberList[i];
                addressWinner[2] = playerList[i];
            }
        }
        
        return addressWinner;
    }
    
    function kill() public {
        require(msg.sender == founder);
        selfdestruct(founder);
    }
}