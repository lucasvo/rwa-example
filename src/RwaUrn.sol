pragma solidity 0.5.12;

contract VatLike {
    function frob(bytes32, address, address, address, int, int) public;
}

contract GemLike {
    function transfer(address, uint) public returns (bool);
    function transferFrom(address, address, uint) public returns (bool);
}

contract JoinLike {
    function join(address, uint256) public;
    function exit(address, uint256) public;
}

contract GemJoinLike is JoinLike {
    function gem() public returns (GemLike);
    function ilk() public returns (bytes32);
}


contract RwaUrn {
    // --- auth ---
    mapping (address => uint) public wards;
    mapping (address => uint) public can;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "RwaUrn/not-authorized");
        _;
    }
    function hope(address usr) external auth { can[usr] = 1; }
    function nope(address usr) external auth { can[usr] = 0; }
    modifier operator {
        require(can[msg.sender] == 1, "RwaUrn/not-operator");
        _;
    }

    VatLike  public vat;
    JoinLike public daiJoin;
    GemJoinLike public gemJoin;
    address  public fbo;

    // --- init ---
    constructor(address vat_, address gemJoin_, address daiJoin_, address fbo_) public {
        vat = VatLike(vat_);
        daiJoin = JoinLike(daiJoin_);
        gemJoin = GemJoinLike(gemJoin_);
        fbo = fbo_;
        wards[msg.sender] = 1;
    }

    // --- administration ---
    function file(bytes32 what, address data) external auth {
        if (what == "fbo") fbo = data;
        else revert("RwaUrn/unrecognised-param");
    }

    // --- cdp operation ---
    // n.b. DAI can only go to fbo
    function lock(uint256 wad) external operator {
        gemJoin.gem().transferFrom(msg.sender, address(this), wad);
        gemJoin.join(address(this), wad);
        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), int(wad), 0);
    }
    function free(uint256 wad) external operator {
        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), -int(wad), 0);
        gemJoin.exit(address(this), wad);
        gemJoin.gem().transfer(msg.sender, wad);
    }
    function draw(uint256 wad) external operator {
        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), 0, int(wad));
        daiJoin.exit(fbo, wad);
    }
    function wipe(uint256 wad) external operator {
        daiJoin.join(address(this), wad);
        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), 0, -int(wad));
    }
}
