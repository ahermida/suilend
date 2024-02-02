module suilend::reserve_config {
    use std::vector::{Self};
    use suilend::decimal::{Decimal, Self, add, sub, mul, div, ge, le};
    use std::option::{Option, Self};

    const EInvalidReserveConfig: u64 = 0;
    const EInvalidUtil: u64 = 1;

    struct ReserveConfig has store, drop {
        // risk params
        open_ltv_pct: u8,
        close_ltv_pct: u8,
        borrow_weight_bps: u64,
        deposit_limit: u64,
        borrow_limit: u64,
        liquidation_bonus_pct: u8,

        // interest params
        interest_rate_utils: vector<u8>,
        interest_rate_aprs: vector<u64>,

        // fees
        borrow_fee_bps: u64,
        spread_fee_bps: u64,
        liquidation_fee_bps: u64,
    }

    struct ReserveConfigBuilder has store, drop {
        open_ltv_pct: Option<u8>,
        close_ltv_pct: Option<u8>,
        borrow_weight_bps: Option<u64>,
        deposit_limit: Option<u64>,
        borrow_limit: Option<u64>,
        liquidation_bonus_pct: Option<u8>,
        interest_rate_utils: Option<vector<u8>>,
        interest_rate_aprs: Option<vector<u64>>,
        borrow_fee_bps: Option<u64>,
        spread_fee_bps: Option<u64>,
        liquidation_fee_bps: Option<u64>,
    }

    public fun create_reserve_config(
        open_ltv_pct: u8, 
        close_ltv_pct: u8, 
        borrow_weight_bps: u64, 
        deposit_limit: u64, 
        borrow_limit: u64, 
        liquidation_bonus_pct: u8,
        borrow_fee_bps: u64, 
        spread_fee_bps: u64, 
        liquidation_fee_bps: u64, 
        interest_rate_utils: vector<u8>,
        interest_rate_aprs: vector<u64>,
    ): ReserveConfig {
        let config = ReserveConfig {
            open_ltv_pct,
            close_ltv_pct,
            borrow_weight_bps,
            deposit_limit,
            borrow_limit,
            liquidation_bonus_pct,
            interest_rate_utils,
            interest_rate_aprs,
            borrow_fee_bps,
            spread_fee_bps,
            liquidation_fee_bps,
        };

        validate_reserve_config(&config);
        config
    }

    fun validate_reserve_config(config: &ReserveConfig) {
        assert!(config.open_ltv_pct <= 100, EInvalidReserveConfig);
        assert!(config.close_ltv_pct <= 100, EInvalidReserveConfig);
        assert!(config.open_ltv_pct <= config.close_ltv_pct, EInvalidReserveConfig);

        assert!(config.borrow_weight_bps >= 10_000, EInvalidReserveConfig);
        assert!(config.liquidation_bonus_pct <= 20, EInvalidReserveConfig);

        assert!(config.borrow_fee_bps <= 10_000, EInvalidReserveConfig);
        assert!(config.spread_fee_bps <= 10_000, EInvalidReserveConfig);
        assert!(config.liquidation_fee_bps <= 10_000, EInvalidReserveConfig);

        validate_utils_and_aprs(&config.interest_rate_utils, &config.interest_rate_aprs);
    }

    fun validate_utils_and_aprs(utils: &vector<u8>, aprs: &vector<u64>) {
        assert!(vector::length(utils) >= 2, EInvalidReserveConfig);
        assert!(
            vector::length(utils) == vector::length(aprs), 
            EInvalidReserveConfig
        );

        let length = vector::length(utils);
        assert!(*vector::borrow(utils, 0) == 0, EInvalidReserveConfig);
        assert!(*vector::borrow(utils, length-1) == 100, EInvalidReserveConfig);

        // check that both vectors are strictly increasing
        let i = 1;
        while (i < length) {
            assert!(*vector::borrow(utils, i - 1) < *vector::borrow(utils, i), EInvalidReserveConfig);
            assert!(*vector::borrow(aprs, i - 1) < *vector::borrow(aprs, i), EInvalidReserveConfig);

            i = i + 1;
        }
    }

    public fun open_ltv(config: &ReserveConfig): Decimal {
        decimal::from_percent(config.open_ltv_pct)
    }

    public fun close_ltv(config: &ReserveConfig): Decimal {
        decimal::from_percent(config.close_ltv_pct)
    }

    public fun borrow_weight(config: &ReserveConfig): Decimal {
        decimal::from_bps(config.borrow_weight_bps)
    }

    public fun deposit_limit(config: &ReserveConfig): u64 {
        config.deposit_limit
    }

    public fun borrow_limit(config: &ReserveConfig): u64 {
        config.borrow_limit
    }

    public fun liquidation_bonus(config: &ReserveConfig): Decimal {
        decimal::from_percent(config.liquidation_bonus_pct)
    }

    public fun borrow_fee(config: &ReserveConfig): Decimal {
        decimal::from_bps(config.borrow_fee_bps)
    }

    public fun liquidation_fee(config: &ReserveConfig): Decimal {
        decimal::from_bps(config.liquidation_fee_bps)
    }

    public fun calculate_apr(config: &ReserveConfig, cur_util: Decimal): Decimal {
        assert!(le(cur_util, decimal::from(1)), EInvalidUtil);

        let length = vector::length(&config.interest_rate_utils);

        let i = 1;
        while (i < length) {
            let left_util = decimal::from_percent(*vector::borrow(&config.interest_rate_utils, i - 1));
            let right_util = decimal::from_percent(*vector::borrow(&config.interest_rate_utils, i));

            if (ge(cur_util, left_util) && le(cur_util, right_util)) {
                let left_apr = decimal::from_percent_u64(*vector::borrow(&config.interest_rate_aprs, i - 1));
                let right_apr = decimal::from_percent_u64(*vector::borrow(&config.interest_rate_aprs, i));

                let weight = div(
                    sub(cur_util, left_util),
                    sub(right_util, left_util)
                );

                let apr_diff = sub(right_apr, left_apr);
                return add(
                    left_apr,
                    mul(weight, apr_diff)
                )
            };

            i = i + 1;
        };

        // should never get here
        assert!(1 == 0, EInvalidReserveConfig);
        decimal::from(0)
    }


    // === Tests ==
    #[test]
    fun test_valid_reserve_config() {
        let utils = vector::empty();
        vector::push_back(&mut utils, 0);
        vector::push_back(&mut utils, 100);

        let aprs = vector::empty();
        vector::push_back(&mut aprs, 0);
        vector::push_back(&mut aprs, 100);

        create_reserve_config(
            10,
            10,
            10_000,
            1,
            1,
            5,
            10,
            2000,
            3000,
            utils,
            aprs
        );
    }

    // TODO: there are so many other invalid states to test
    #[test]
    #[expected_failure(abort_code = EInvalidReserveConfig)]
    fun test_invalid_reserve_config() {
        create_reserve_config(
            // open ltv pct
            10,
            // close ltv pct
            9,
            // borrow weight bps
            10_000,
            // deposit_limit
            1,
            // borrow_limit
            1,
            // liquidation bonus pct
            5,
            // borrow fee bps
            10,
            // spread fee bps
            2000,
            // liquidation fee bps
            3000,
            // utils
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 100);
                v
            },
            // aprs
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 100);
                v
            }
        );
    }

    #[test_only]
    fun example_reserve_config(): ReserveConfig {
        create_reserve_config(
            // open ltv pct
            10,
            // close ltv pct
            10,
            // borrow weight bps
            10_000,
            // deposit_limit
            1,
            // borrow_limit
            1,
            // liquidation bonus pct
            5,
            // borrow fee bps
            10,
            // spread fee bps
            2000,
            // liquidation fee bps
            3000,
            // utils
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 100);
                v
            },
            // aprs
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 31536000);
                v
            }
        )
    }

    public fun from(config: &ReserveConfig): ReserveConfigBuilder {
        ReserveConfigBuilder {
            open_ltv_pct: option::some(config.open_ltv_pct),
            close_ltv_pct: option::some(config.close_ltv_pct),
            borrow_weight_bps: option::some(config.borrow_weight_bps),
            deposit_limit: option::some(config.deposit_limit),
            borrow_limit: option::some(config.borrow_limit),
            liquidation_bonus_pct: option::some(config.liquidation_bonus_pct),
            interest_rate_utils: option::some(config.interest_rate_utils),
            interest_rate_aprs: option::some(config.interest_rate_aprs),
            borrow_fee_bps: option::some(config.borrow_fee_bps),
            spread_fee_bps: option::some(config.spread_fee_bps),
            liquidation_fee_bps: option::some(config.liquidation_fee_bps),
        }
    }

    public fun set_open_ltv_pct(builder: &mut ReserveConfigBuilder, open_ltv_pct: u8) {
        builder.open_ltv_pct = option::some(open_ltv_pct);
    }

    public fun set_close_ltv_pct(builder: &mut ReserveConfigBuilder, close_ltv_pct: u8) {
        builder.close_ltv_pct = option::some(close_ltv_pct);
    }

    public fun build(builder: ReserveConfigBuilder): ReserveConfig {
        create_reserve_config(
            option::extract(&mut builder.open_ltv_pct),
            option::extract(&mut builder.close_ltv_pct),
            option::extract(&mut builder.borrow_weight_bps),
            option::extract(&mut builder.deposit_limit),
            option::extract(&mut builder.borrow_limit),
            option::extract(&mut builder.liquidation_bonus_pct),
            option::extract(&mut builder.borrow_fee_bps),
            option::extract(&mut builder.spread_fee_bps),
            option::extract(&mut builder.liquidation_fee_bps),
            option::extract(&mut builder.interest_rate_utils),
            option::extract(&mut builder.interest_rate_aprs),
        )
    }



    #[test_only]
    public fun default_reserve_config(): ReserveConfig {
        create_reserve_config(
            // open ltv pct
            50,
            // close ltv pct
            80,
            // borrow weight bps
            10_000,
            // deposit_limit
            0,
            // borrow_limit
            0,
            // liquidation bonus pct
            0,
            // borrow fee bps
            0,
            // spread fee bps
            0,
            // liquidation fee bps
            0,
            // utils
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 100);
                v
            },
            // aprs
            {
                let v = vector::empty();
                vector::push_back(&mut v, 0);
                vector::push_back(&mut v, 1);
                v
            }
        )
    }

    // TODO tests for validate_utils_and_aprs

    #[test]
    fun test_calculate_apr() {
        let config = example_reserve_config();
        config.interest_rate_utils = {
            let v = vector::empty();
            vector::push_back(&mut v, 0);
            vector::push_back(&mut v, 10);
            vector::push_back(&mut v, 100);
            v
        };
        config.interest_rate_aprs = {
            let v = vector::empty();
            vector::push_back(&mut v, 0);
            vector::push_back(&mut v, 100);
            vector::push_back(&mut v, 1000);
            v
        };

        assert!(calculate_apr(&config, decimal::from_percent(0)) == decimal::from(0), 0);
        assert!(calculate_apr(&config, decimal::from_percent(5)) == decimal::from_percent(50), 0);
        assert!(calculate_apr(&config, decimal::from_percent(10)) == decimal::from_percent(100), 0);
        assert!(calculate_apr(&config, decimal::from_percent(55)) == decimal::from_percent_u64(550), 0);
        assert!(calculate_apr(&config, decimal::from_percent(100)) == decimal::from_percent_u64(1000), 0);
    }
}