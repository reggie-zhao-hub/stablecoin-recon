# Stablecoin Reserve Reconciliation (dbt)

A dbt project that implements the daily reserve reconciliation required of licensed stablecoin issuers under Hong Kong's Stablecoins Ordinance — as a runnable, tested data pipeline.

## Background

Hong Kong's Stablecoins Ordinance (Cap. 656, in force since 1 August 2025) requires every licensed stablecoin issuer to maintain full backing:

> the market value of the specified reserve assets pool ... is at all times at least equal to the par value of the outstanding specified stablecoins ... in circulation
> — Schedule 2, Section 5(2)

The HKMA's *Guideline on Supervision of Licensed Stablecoin Issuers* (para 2.2.1) turns this into an operational duty:

> ... conducting regular reconciliation between the market value of the reserve assets and the par value of the outstanding specified stablecoins in circulation

This project implements that reconciliation as a dbt model: aggregate reserve holdings by date, compare against circulating par value, compute the buffer, and flag whether full backing holds.

## What it does

| Layer | File | Purpose |
|---|---|---|
| Source data | `seeds/daily_circulation.csv` | Daily par value of stablecoins in circulation |
| Source data | `seeds/reserve_holdings.csv` | Daily reserve holdings by asset type (cash, treasury) |
| Model | `models/daily_reconciliation.sql` | Daily reconciliation: reserve value vs par value |
| Tests | `models/schema.yml` | Data quality: unique date, non-null flags |

Output columns:

- `reserve_value` — market value of reserve assets on that date
- `par_value` — par value of stablecoins in circulation
- `buffer` — reserve value minus par value (over-collateralisation headroom)
- `is_fully_backed` — true if `reserve_value >= par_value`

## Project structure

```
stablecoin_recon/
├── dbt_project.yml                 project configuration
├── profiles.yml                    warehouse connection (DuckDB)
├── seeds/
│   ├── daily_circulation.csv       circulating par value by date
│   └── reserve_holdings.csv        reserve holdings by date and asset type
└── models/
    ├── daily_reconciliation.sql    the reconciliation model
    └── schema.yml                  data quality tests
```

## How to run

```bash
pip install dbt-oss        # dbt v2, DuckDB adapter built in
dbt seed                   # load the CSVs into DuckDB
dbt run                    # build the reconciliation model
dbt test                   # run the data quality checks
dbt show --select daily_reconciliation   # print the result
```

No warehouse account, credit card or cloud setup required — DuckDB is embedded and the whole project runs locally.

## Sample output

```
┌────────────┬───────────┬───────────────┬─────────┬─────────────────┐
│ date       ┆ par_value ┆ reserve_value ┆ buffer  ┆ is_fully_backed │
╞════════════╪═══════════╪═══════════════╪═════════╪═════════════════╡
│ 2026-01-01 ┆ 100000000 ┆ 101000000     ┆ 1000000 ┆ true            │
│ 2026-01-02 ┆ 100500000 ┆ 101000000     ┆ 500000  ┆ true            │
│ 2026-01-03 ┆ 101000000 ┆ 102000000     ┆ 1000000 ┆ true            │
└────────────┴───────────┴───────────────┴─────────┴─────────────────┘
```

## Design notes

- **`>=` rather than `>`** — the Ordinance requires reserve value to be *at least equal to* par value, so exactly 100% backing is compliant. The comparison follows the statutory wording, not a stricter convention.
- **`buffer` is surfaced, not hidden** — the HKMA expects over-collateralisation to absorb market movements, so the model exposes the headroom explicitly instead of collapsing everything into a boolean.
- **Tests mirror auditability** — the test suite runs on every build because the supervisory guideline requires reserve figures to be verifiable as of a *randomly selected* business day, not only at period end.
- **`ref()` throughout** — dependencies are declared rather than hard-coded, so the DAG is traceable and dbt resolves execution order.

## Portability

The models are plain SQL. Moving from DuckDB to Snowflake, BigQuery or Redshift means editing `profiles.yml` only; the reconciliation logic and tests carry over unchanged.

## Scope and limitations

This is a demonstration project built on synthetic sample data. A production implementation would additionally require:

- Ingestion from on-chain mint/burn events and custodian statements
- Market price feeds with bid-price valuation
- Daily and weekly regulatory reporting formats
- Integration with the external attestation and annual audit cycle

## References

- Stablecoins Ordinance (Cap. 656), Schedule 2, section 5 — reserve assets and full backing
- HKMA, *Guideline on Supervision of Licensed Stablecoin Issuers* — section 2.2 (full backing), section 2.7 (disclosure and reporting)
