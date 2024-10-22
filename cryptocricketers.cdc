import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

pub contract CryptoCricketers: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    // The total number of CryptoCricketers that have been minted
    //
    pub var totalSupply: UInt64
    
    access(self) var nameData: {String: String}

    // A CryptoCricketer as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let description: String
        pub let asset_uri: String
        pub let name: String
        pub let attributes: {String: String}
        pub let symbol: String
        pub let royalty: Int
        pub let stats_uri: String
        pub let project_uri: String
        pub let serial_number: Int
        pub let collection: String


        init(
            id: UInt64, 
            description: String,
            asset_uri: String,
            name: String,
            attributes: {String: String},
            symbol: String,
            royalty: Int,
            stats_uri: String,
            project_uri: String,
            serial_number: Int,
            collection: String
            ) {
            self.id = id
            self.description = description
            self.asset_uri = asset_uri
            self.name = name
            self.attributes = attributes
            self.symbol = symbol
            self.royalty = royalty
            self.stats_uri = stats_uri
            self.project_uri = project_uri
            self.serial_number = serial_number
            self.collection = collection
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.asset_uri, 
                            path: "sm.png"
                        )
                    )
            }

            return nil
        }
    }

    // This is the interface that users can cast their CryptoCricketers Collection as
    // to allow others to deposit CryptoCricketers into their Collection. It also allows for reading
    // the details of CryptoCricketers in the Collection.
    pub resource interface CryptoCricketersCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowCryptoCricketer(id: UInt64): &CryptoCricketers.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow CryptoCricketer reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of CryptoCricketer NFTs owned by an account
    //
    pub resource Collection: CryptoCricketersCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @CryptoCricketers.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        // borrowCryptoCricketer
        // Gets a reference to an NFT in the collection as a CryptoCricketer,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the CryptoCricketer.
        //
        pub fun borrowCryptoCricketer(id: UInt64): &CryptoCricketers.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &CryptoCricketers.NFT
            } else {
                return nil
            }
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic}, 
            description: String,
            asset_uri: String,
            name: String,
            attributes: {String: String},
            symbol: String,
            royalty: Int,
            stats_uri: String,
            project_uri: String,
            serial_number: Int,
            collection: String
        ) {
            pre {
                    CryptoCricketers.nameData[name] == nil: "Cannot create NFT: Name Already Exists"
                }

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create CryptoCricketers.NFT(
                id: CryptoCricketers.totalSupply,
                description: description,
                asset_uri: asset_uri,
                name: name,
                attributes: attributes,
                symbol: symbol,
                royalty: royalty,
                stats_uri: stats_uri,
                project_uri: project_uri,
                serial_number: serial_number,
                collection: collection
            ))

            CryptoCricketers.nameData[name] = name


            emit Minted(
                id: CryptoCricketers.totalSupply,
                name: name
            )

            CryptoCricketers.totalSupply = CryptoCricketers.totalSupply + (1 as UInt64)
        }
    }

    // fetch
    // Get a reference to a CryptoCricketer from an account's Collection, if available.
    // If an account does not have a CryptoCricketers.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &CryptoCricketers.NFT? {
        let collection = getAccount(from)
            .getCapability(CryptoCricketers.CollectionPublicPath)!
            .borrow<&CryptoCricketers.Collection{CryptoCricketers.CryptoCricketersCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust CryptoCricketers.Collection.borowCryptoCricketer to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowCryptoCricketer(id: itemID)
    }

    // initializer
    //
    init() {
        // set rarity price mapping

        // Set our named paths
        self.CollectionStoragePath = /storage/CryptoCricketersCollection
        self.CollectionPublicPath = /public/CryptoCricketersCollection
        self.MinterStoragePath = /storage/CryptoCricketersMinter

        // Initialize the total supply
        self.totalSupply = 0

        // Initialize the name data
        self.nameData = {}


        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
