# Project Overview

Infinity Wellness is an employee wellness mobile app with a protected Wallet SDK. An employee can activate an Employee Wallet, view and receive Wellness Points, review and send transfers with device authentication, inspect confirmed activity, update protected service settings, and create an encrypted user-held backup. Wellness Admin provides activation, points policy, public asset-holder, and protected service configuration flows.

Employee-facing language is **Employee**, **Wellness Points**, and **Employee Wallet**. SDK methods and protocol fields retain their source Builder/distributor names to preserve the public API and stored-data compatibility. The source Infinity App's Supabase, mini-app, and live-data features are outside this project.

Wallet operations use the configured Stellar Horizon service through the private SDK. Wellness Admin's asset-holder list exposes public ledger accounts and balances; it is not an employee directory. Role authorization, physical-device verification, release operations, and independent security review remain required before production use.
