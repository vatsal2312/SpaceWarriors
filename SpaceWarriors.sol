// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

/**
* @title Mint Space warrior collection
* @notice This contract mint NFT linked to an IPFS file
*/

contract SpaceWarriors is ERC721Enumerable, Ownable {

using Strings for uint256;

// Merkle root of the whitelist
bytes32 public _merkleRoot;

// Max supply
uint _maxSupply = 7777;

// Amount of reserved token
uint public _reserved = 100;

// Price token in ether
uint public _price = 0.1 ether;

// Max token by wallet
uint public _maxNftByWallet = 3;

// Contract status. If paused, no one can mint
bool public _paused = true;

// Sell status. Presale if true and public sale if false
bool public _presale = true;

// Address of the team wallet
address payable _team;

//Flag allowing the set of the base URI only once
bool public _baseURIset = false;

/**
* @dev NFT configuration
* _revealed: Lock/Unlock the final URI. Link to the hidden URI if false
* baseURI : URI of the revealed NFT
* _hideURI : URI of the non revealed NFT
*/
bool _revealed = false;
string baseURI;
string _hideURI;

//Event to follow a phase switch
event switchPhase();

/**

* @dev Modifier isWhitelisted to check if the caller is on the whitelist
*/
modifier isWhitelisted(bytes32 [] calldata merkleProof){
bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
require(MerkleProof.verify(merkleProof, _merkleRoot, leaf), "Not in the whitelist");
_;
}

/**
* @dev Initializes tbe contract with:
* initURI: the final URI after reveal in a format eg:
"ipfs://QmdsxxxxxxxxxxxxxxxxxxepJF/"
* hiddenURI: the initial URI before the reveal, in a complete format eg:
"ipfs://QmdsxxxxxxxxxxxxxxxxxxepJF/hidden.json"
* merkleRoot: the merkle root of the whitelist
* team: Address of the team wallet
*/
constructor (//string memory initURI,
string memory hiddenURI,
bytes32 merkleRoot,
address payable team

) ERC721("SpaceWarriors", "SPW"){
_team = team;
//baseURI = initURI;
_hideURI = hiddenURI;
_merkleRoot = merkleRoot;
_safeMint(team, 0);

}

/**

* @dev Switch the status of the contract
*
* In pause state if `_paused` is true, no one can mint but the owner
*
*/
function switchPauseStatus () external onlyOwner (){
_paused = !_paused;
}

/**
* @dev End the presale
*
* If `_presale` = false, the contract is in public sale mode
*
*/
function endPresale () external onlyOwner (){
_presale = false;
emit switchPhase();
}

/**
* @dev Change the `_price` of the token for `newPrice`
*/
function setNewPrice (uint newPrice) external onlyOwner (){
_price = newPrice;
}

/**
* @dev Minting for whitelisted addresses
*
* Requirements:

*
* Contract must be unpaused
* The presale must be going on
* The caller must request less than the max by address authorized
* The amount of token must be superior to 0
* The supply must not be empty
* The price must be correct
*
* @param amountToMint the number of token to mint
* @param merkleProof for the wallet address
*
*/
function whitlistedMinting (uint amountToMint, bytes32[] calldata
merkleProof ) external payable isWhitelisted(merkleProof) {
require (!_paused, "Contract paused");
require (_presale, "Presale over!");
require (amountToMint + balanceOf(msg.sender) <= _maxNftByWallet,
"Requet too much for a wallet");
require (amountToMint > 0, "Error in the amount requested");
require (amountToMint + totalSupply() <= _maxSupply - _reserved,
"Request superior max Supply");
require (msg.value >= _price*amountToMint, "Insuficient funds");

_mintNFT(amountToMint);
}

/**
* @dev Updating the merkel root
*
* @param newMerkleRoot must start with 0x
*
*/
function updateMerleRoot ( bytes32 newMerkleRoot) external onlyOwner{

_merkleRoot = newMerkleRoot;
emit switchPhase();
}

/**
* @dev Updating the max allowed in each wallet
*/
function updateMaxByWallet (uint newMaxNftByWallet) external
onlyOwner{
_maxNftByWallet = newMaxNftByWallet;
}

/**
* @dev Minting for the public sale
*
* Requirements:
*
* The presale must be over
* The caller must request less than the max by address authorized
* The amount of token must be superior to 0
* The supply must not be empty
* The price must be correct
*
* @param amountToMint the number of token to mint
*
*/
function publicMint(uint amountToMint) external payable{
require (!_paused, "Contract paused");
require (!_presale, "Presale on");
require (amountToMint + balanceOf(msg.sender) <= _maxNftByWallet,
"Requet too much for a wallet");
require (amountToMint > 0, "Error in the amount requested");
require (amountToMint + totalSupply() <= _maxSupply - _reserved,

"Request superior max Supply");
require (msg.value >= _price*amountToMint, "Insuficient funds");

_mintNFT(amountToMint);
}

/**
* @dev Give away attribution
*
* Requirements:
*
* The recipient must be different than 0
* The amount of token requested must be within the reverse
* The amount requested must be supperior to 0
*
*/
function giveAway (address to, uint amountToMint) external onlyOwner{
require (to != address(0), "address 0 requested");
require (amountToMint <= _reserved, "You requested more than the reserved token");
require (amountToMint > 0, "Amount Issue");

uint currentSupply = totalSupply();
_reserved = _reserved - amountToMint;
for (uint i; i < amountToMint ; i++) {
_safeMint(to, currentSupply + i);
}
}

/**
* @dev Mint the amount of NFT requested
*/
function _mintNFT(uint _amountToMint) internal {

uint currentSupply = totalSupply();
for (uint i; i < _amountToMint ; i++) {
_safeMint(msg.sender, currentSupply + i);
}
}

/**
* @dev Team withdraw on the `_team` wallet
*/
function withdraw () external onlyOwner{
require(address(this).balance != 0, "Nothing to withdraw");
(bool success, ) = _team.call{value: address(this).balance }("");
require(success, 'transfer failed');
}

/**
* @dev Return an array of token Id owned by `owner`
*/
function getWallet(address _owner) public view returns(uint [] memory){
uint numberOwned = balanceOf(_owner);
uint [] memory idItems = new uint[](numberOwned);

for (uint i = 0; i < numberOwned; i++){
idItems[i] = tokenOfOwnerByIndex(_owner,i);
}
return idItems;
}

/**
* @dev Reveal the final URI
*/
function revealNFT() public onlyOwner {

_revealed = true;
}

/**
* @dev ERC721 standard
* @return baseURI value
*/
function _baseURI() internal view virtual override returns (string memory) {
return baseURI;
}

/**
* @dev Set the base URI
*
* The owner set the base URI only once !!!!!
* The style MUST BE as follow :
"ipfs://QmdsaXXXXXXXXXXXXXXXXXXXX7epJF/"
*/
function setBaseURI(string memory newBaseURI) public onlyOwner {
require (!_baseURIset, "Base URI has already be set");
_baseURIset = true;
baseURI = newBaseURI;
}

/**
* @dev Return the URI of the NFT
* @notice return the hidden URI then the Revealed JSON when the
Revealed param is true
*/
function tokenURI(uint256 tokenId) public view virtual override returns
(string memory) {
require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");

if(_revealed == false) {
return _hideURI;
}
string memory URI = _baseURI();
return bytes(URI).length > 0 ? string(abi.encodePacked(URI,
tokenId.toString(), ".json")) : "";
}
}
