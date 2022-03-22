import {
  Field,
  PrivateKey,
  PublicKey,
  SmartContract,
  state,
  State,
  method,
  Mina,
  isReady,
  shutdown,
  UInt64,
  Party,
} from "snarkyjs";

class CustomExercise extends SmartContract {
  @state(Field) x: State<Field>;
  @state(Field) y: State<Field>;
  @state(Field) z: State<Field>;

  constructor(
    initialBalance: UInt64,
    address: PublicKey,
    x: Field,
    y: Field,
    z: Field
  ) {
    super(address);

    this.balance.addInPlace(initialBalance);

    this.x = State.init(x);
    this.y = State.init(y);
    this.z = State.init(z);
  }

  @method async update(i: Field) {
    const x = await this.x.get();
    const y = await this.y.get();
    const z = await this.z.get();

    this.x.set(x.mul(i));
    this.y.set(y.mul(i.mul(2)));
    this.z.set(z.mul(i.mul(3)));
  }
}

export async function run() {
  await isReady;

  const Local = Mina.LocalBlockchain();
  Mina.setActiveInstance(Local);
  const account1 = Local.testAccounts[0].privateKey;
  const account2 = Local.testAccounts[1].privateKey;

  const snappPrivkey = PrivateKey.random();
  const snappPubkey = snappPrivkey.toPublicKey();

  let snappInstance: CustomExercise;

  const initX = new Field(3);
  const initY = new Field(4);
  const initZ = new Field(5);

  // Deploys the snapp
  await Mina.transaction(account1, async () => {
    // account2 sends 1000000000 to the new snapp account
    const amount = UInt64.fromNumber(1000000000);
    const p = await Party.createSigned(account2);
    p.balance.subInPlace(amount);

    snappInstance = new CustomExercise(
      amount,
      snappPubkey,
      initX,
      initY,
      initZ
    );
  })
    .send()
    .wait();

  // Update the snapp
  await Mina.transaction(account1, async () => {
    // x = 3 * 2 = 6
    // y = 4 * 2 * 2 = 16
    // z = 5 * 2 * 3 = 30
    await snappInstance.update(new Field(2));
  })
    .send()
    .wait();

  const intermediateAcc = await Mina.getAccount(snappPubkey);

  console.log("Custom Exercise");
  console.log(
    "intermediate state value: ",
    [
      intermediateAcc.snapp.appState[0].toString(),
      intermediateAcc.snapp.appState[1].toString(),
      intermediateAcc.snapp.appState[2].toString(),
    ].join(", ")
  );

  // Update the snapp again
  await Mina.transaction(account1, async () => {
    // x = 6 * 1 = 6
    // y = 16 * 2 = 32
    // z = 30 * 3 = 90
    await snappInstance.update(new Field(1));
  })
    .send()
    .wait();

  const finalAcc = await Mina.getAccount(snappPubkey);

  console.log(
    "final state value: ",
    [
      finalAcc.snapp.appState[0].toString(),
      finalAcc.snapp.appState[1].toString(),
      finalAcc.snapp.appState[2].toString(),
    ].join(", ")
  );
}

run();
shutdown();
