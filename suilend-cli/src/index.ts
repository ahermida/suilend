import * as fs from "fs";
import { SuiPriceServiceConnection } from "@pythnetwork/pyth-sui-js";
import { SuiPythClient } from "@pythnetwork/pyth-sui-js";
import {
  Connection,
  Ed25519Keypair,
  JsonRpcProvider,
  RawSigner,
  SUI_CLOCK_OBJECT_ID,
  TransactionBlock,
  fromB64,
} from "@mysten/sui.js";
import { load, ObligationOwnerCap, Obligation, Reserve, LendingMarket } from "./types";
import { SuilendClient } from "./client";

// replace <YOUR_SUI_ADDRESS> with your actual address, which is in the form 0x123...
const MY_ADDRESS =
  "0x4f3446baf9ca583b920e81924b94883b64addc2a2671963b546aaef77f79a28b";
const SUILEND_CONTRACT_ADDRESS =
  "0xd4b22ab40c4e3ef2f90cef9432bde18bea223d06644a111921383821344cb340";

async function main() {
  // create a new SuiClient object pointing to the network you want to use
  const lendingMarketId =
    "0xa6d1603c50fd4fac1ae544744930b37f3c3467c6b10e60bc0db5673d764a1647";
  // const sui_metadata = await client.getCoinMetadata({ coinType: '0x2::sui::SUI' })!;
  const client = new JsonRpcProvider(
    new Connection({ fullnode: "https://fullnode.mainnet.sui.io:443" })
  );
  const suilendClient = new SuilendClient(lendingMarketId, client);
  await suilendClient.initialize();

  const obligationOwnerCapId =
    "0xc0201eb13d4507cfb078d2f5bde94b9f02b1720a3883a8b8a7f0544029d8985d";
  // Obligation.fetch()

  const keypair = Ed25519Keypair.fromSecretKey(
    fromB64(process.env.SUI_SECRET_KEY!)
  );
  const signer = new RawSigner(keypair, client);

  let txb = new TransactionBlock();
  suilendClient.withdraw(obligationOwnerCapId, "0x2::sui::SUI", 1000000000, txb);

  let obligationOwnerCap = await load(client, ObligationOwnerCap, obligationOwnerCapId);
  console.log(obligationOwnerCap);

  let obligation = await load(client, Obligation, obligationOwnerCap.obligation_id.bytes);
  console.log(obligation);

  let lendingMarket = await load(client, LendingMarket, lendingMarketId);
  console.log(JSON.stringify(lendingMarket, null, 2));


  // await suilendClient.createReserve(
  //   txb,
  //   {
  //     open_ltv_pct: 100,
  //     close_ltv_pct: 150,
  //     borrow_weight_bps: 100,
  //     deposit_limit: 1000000000,
  //     borrow_limit: 1000000000,
  //     borrow_fee_bps: 0,
  //     spread_fee_bps: 0,
  //     liquidation_fee_bps: 0,
  //     interest_rate_utils: [0],
  //     interest_rate_aprs: [0]
  //   },
  //   "0x2::sui::SUI",
  //   "0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744"
  // );

  // const [obligationOwnerCap] = suilendClient.createObligation(txb);
  // txb.transferObjects([obligationOwnerCap], txb.pure(MY_ADDRESS));

  // suilendClient.deposit(
  //   "0x2e7aebd6459194bd4ab72b0d82981a6371369166f4256ab4c11cfd08e8ab52e2",
  //   "0x2::sui::SUI",
  //   obligationOwnerCap,
  //   txb
  // );

  const res = await signer.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showBalanceChanges: true,
      showEffects: true,
      showInput: true,
      showObjectChanges: true,
    },
  });
  console.log(res);

  // const { bytes, signature } = await txb.sign({ client: suiClient, signer: keypair })
  // suiClient.executeTransactionBlock({
  //   tra

  // })

  // Convert MIST to Sui
}

main();