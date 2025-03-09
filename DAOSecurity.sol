/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
  Slockit's DAOSecurity proposal
*/

// use this http://solidity.readthedocs.io/en/latest/layout-of-source-files.html#use-in-actual-compilers
// solidity feature in order to point to the DAO's location when compiling with
// the command line solc compiler.
//
// example:
// solc DAO=/home/lefteris/ew/DAO DAOSecurity.sol
import "DAO/DAO.sol";

contract DAOSecurity {

    // The total cost of the Offer. Exactly this amount is transfered from the
    // Client to the Offer contract when the Offer is signed by the Client.
    // Set once by the Offerer.
    uint totalCosts;

    // Initial withdraw to the Contractor. It is done the moment the Offer is
    // signed.
    // Set once by the Offerer.
    uint oneTimeCosts;

    // The minimal daily withdraw limit that the Contractor accepts.
    // Set once by the Offerer.
    uint128 minDailyWithdrawLimit;

    // The amount of wei the Contractor has right to withdraw daily above the
    // initial withdraw. The Contractor does not have to do the withdraws every
    // day as this amount accumulates.
    uint128 dailyWithdrawLimit;

    // The address of the Contractor.
    address contractor;

    // The hash of the Proposal/Offer document.
    bytes32 hashOfTheProposalDocument;

    // The time of the last withdraw to the Contractor.
    uint lastPayment;

    uint dateOfSignature;
    DAO client; // address of DAO
    DAO originalClient; // address of DAO who signed the contract
    bool isContractValid;

    modifier onlyClient {
        if (msg.sender != address(client))
            throw;
        _
    }

    // Prevents methods from perfoming any value transfer
    modifier noEther() {if (msg.value > 0) throw; _}

    function DAOSecurity(
        address _contractor,
        address _client,
        bytes32 _hashOfTheProposalDocument,
        uint _totalCosts,
        uint _oneTimeCosts,
        uint128 _minDailyWithdrawLimit
    ) {
        contractor = _contractor;
        originalClient = DAO(_client);
        client = DAO(_client);
        hashOfTheProposalDocument = _hashOfTheProposalDocument;
        totalCosts = _totalCosts;
        oneTimeCosts = _oneTimeCosts;
        minDailyWithdrawLimit = _minDailyWithdrawLimit;
        dailyWithdrawLimit = _minDailyWithdrawLimit;
    }

    // non-value-transfer getters
    function getTotalCosts() noEther constant returns (uint) {
        return totalCosts;
    }

    function getOneTimeCosts() noEther constant returns (uint) {
        return oneTimeCosts;
    }

    function getMinDailyWithdrawLimit() noEther constant returns (uint128) {
        return minDailyWithdrawLimit;
    }

    function getDailyWithdrawLimit() noEther constant returns (uint128) {
        return dailyWithdrawLimit;
    }

    function getContractor() noEther constant returns (address) {
        return contractor;
    }

    function getHashOfTheProposalDocument() noEther constant returns (bytes32) {
        return hashOfTheProposalDocument;
    }

    function getLastPayment() noEther constant returns (uint) {
        return lastPayment;
    }

    function getDateOfSignature() noEther constant returns (uint) {
        return dateOfSignature;
    }

    function getClient() noEther constant returns (DAO) {
        return client;
    }

    function getOriginalClient() noEther constant returns (DAO) {
        return originalClient;
    }

    function getIsContractValid() noEther constant returns (bool) {
        return isContractValid;
    }

    function sign() {
        if (msg.sender != address(originalClient) // no good samaritans give us ether
            || msg.value != totalCosts    // no under/over payment
            || dateOfSignature != 0)      // don't sign twice
            throw;
        if (!contractor.send(oneTimeCosts))
            throw;
        dateOfSignature = now;
        isContractValid = true;
        lastPayment = now;
    }

    function setDailyWithdrawLimit(uint128 _dailyWithdrawLimit) onlyClient noEther {
        if (_dailyWithdrawLimit >= minDailyWithdrawLimit)
            dailyWithdrawLimit = _dailyWithdrawLimit;
    }

    // "fire the contractor"
    function returnRemainingEther() onlyClient {
        if (originalClient.DAOrewardAccount().call.value(this.balance)())
            isContractValid = false;
    }

    // Withdraw to the Contractor.
    //
    // Withdraw the amount of ether the Contractor has right to according to
    // the current withdraw limit.
    // Executing this function before the Offer is signed off by the Client
    // makes no sense as this contract has no ether.
    function getDailyPayment() noEther {
        if (msg.sender != contractor)
            throw;
        uint timeSinceLastPayment = now - lastPayment;
        // Calculate the amount using 1 second precision.
        uint amount = (timeSinceLastPayment * dailyWithdrawLimit) / (1 days);
        if (amount > this.balance) {
            amount = this.balance;
        }
        if (contractor.send(amount))
            lastPayment = now;
    }

    // Change the client DAO by giving the new DAO's address
    // warning: The new DAO must come either from a split of the original
    // DAO or an update via `newContract()` so that it can claim rewards
    function updateClientAddress(DAO _newClient) onlyClient noEther {
        client = _newClient;
    }

    function () {
        throw; // this is a business contract, no donations
    }
}
