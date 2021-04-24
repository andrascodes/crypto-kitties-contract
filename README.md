# crypto-kitties-contract

### ERC165 supportsInterface
Source: https://medium.com/coinmonks/ethereum-standard-erc165-explained-63b54ca0d273

- How to check whether a contract supports an interface:
```solidity
// contracts/StoreReader.sol
pragma solidity 0.5.8;
import "./StoreInterface.sol";
contract StoreReader is StoreInterfaceId {
  function getStoreValue(address store) external view returns (uint256) {
    if (ERC165(storeAddress).supportsInterface(0x75b24222)) {
      return store.getValue();
    }
    revert(“Doesn’t support StoreInterface”)
  }
}
```

- If `getStoreValue` will be called multiple times for the same store address, then the check will be performed every time we call, which is unnecessary and expensive in terms of gas. We can optimize it by making a constructor function to check only once and cache a valid Store address into the contract’s storage, so that the getStoreValue doesn’t need to check that again.

- We are repeating the hardcoded interface ID 0x75b24222 in both StoreReader and Store, we can move it into a StoreInterfaceId contract, and let both Store and StoreReader share this value by inheriting from StoreInterfaceId contract.
```solidity
// StoreInterface.sol
pragma solidity 0.5.8;
contract StoreInterfaceId {
  // StoreInterface.getValue.selector ^ StoreInterface.setValue.selector
  bytes4 internal constant STORE_INTERFACE_ID = 0x75b24222;
}
contract StoreInterface is StoreInterfaceId {
  function getValue() external view returns (uint256);
  function setValue(uint256 v) external;
}
```
- Use `doesContractImolementInterface` in `constructor` of `StoreReader:
```solidity
// StoreReader.sol
pragma solidity 0.5.8;
import "./StoreInterface.sol";
import "./ERC165/ERC165Query.sol";
contract StoreReader is StoreInterfaceId, ERC165Query {
  StoreInterface store;
  constructor (address storeAddress) public {
    require(doesContractImplementInterface(
      storeAddress, STORE_INTERFACE_ID), 
      "Doesn't support StoreInterface");
    store = StoreInterface(storeAddress);
  }
  function readStoreValue() external view returns (uint256) {
    return store.getValue();
  }
}
```

- InterfaceId: ERC165 defines that an interface ID can be calculated as the XOR of all function selectors in the interface. Here's the helper contract `Selector`:
```solidity
// Selector.sol
pragma solidity 0.5.8;
import "./StoreInterface.sol";
contract Selector {
  // 0x75b24222
  function calcStoreInterfaceId() external pure returns (bytes4) {
    StoreInterface i;
    return i.getValue.selector ^ i.setValue.selector;
  }
}
```
- Function selector: a bytes4 value that allows you to perform dynamic invocation of a function, based on the name of the function and the type of each one of the input arguments. You can get it by reading the `.selector` property of a function.
- XOR: any change to the function defined in the interface (name, or arg. types) will result in the interfaceID changing, while the length of the total bytes stays unchanged. No matter how many funcs. are included in the interface.


