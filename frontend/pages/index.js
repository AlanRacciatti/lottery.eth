import Head from "next/head";
import styles from "../styles/Home.module.css";
import Image from "next/image";
import { ethers } from "ethers";

import Lotteries from "../components/Lotteries";
import LotteryModal from "../components/LotteryModal";
import Footer from "../components/Footer";
import { Button } from "web3uikit";

import { useState, useEffect } from "react";
import { useWeb3React } from "@web3-react/core";
import { useNotification } from "web3uikit";
import useContract from "../hooks/useContract";

import handleNewNotification from "../utils/handleNewNotification";
import { alertError } from "../utils/swal";
import Presentation from "../components/Presentation";
import ConnectWallet from "../components/ConnectWallet";
import { appChainId } from "../constants/contract";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const presentationImg = "/presentation.png";

export default function Home() {
  const { account, active, chainId, deactivate } = useWeb3React();

  const dispatch = useNotification();
  const contract = useContract();

  const [lotteries, setLotteries] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const [isCreatingLottery, setIsCreatingLottery] = useState(false);
  const [isBuyingTicket, setIsBuyingTicket] = useState(false);
  const [isDeclaringWinner, setIsDeclaringWinner] = useState(false);

  async function updateLotteries() {
    if (active && chainId == appChainId) {
      try {
        let lotteries = await contract.getLotteries();
        setLotteries(lotteries);
      } catch (error) {
        deactivate();
        alertError("An error ocurred, please try connecting again.");
        console.log(error);
      }
    }
  }

  useEffect(() => {
    if (active) {
      updateLotteries();

      contract.on(
        "LotteryCreated",
        (lotteryId, ticketPrice, prize, endDate) => {
          lotteryId = parseInt(lotteryId);
          updateLotteries();
          handleNewNotification(dispatch, {
            type: "Success",
            title: "Lottery Created",
            message: `Lottery ${lotteryId + 1} created successfully`,
          });

          setIsCreatingLottery(false);
        }
      );

      contract.on("PrizeIncreased", (lotteryId, lotteryPrize) => {
        setIsBuyingTicket(false);
        updateLotteries();

        let parsedLotteryId = parseInt(lotteryId);
        let parsedLotterPrize = ethers.utils.formatEther(lotteryPrize);
        handleNewNotification(dispatch, {
          type: "Success",
          title: "Prize Increased",
          message: `Prize of lottery ${
            parsedLotteryId + 1
          } increased to ${parsedLotterPrize}`,
        });
      });

      contract.on("WinnerDeclared", (requestId, lotteryId, winner) => {
        let parsedLotteryId = parseInt(lotteryId);

        setIsDeclaringWinner(false);
        updateLotteries();
        handleNewNotification(dispatch, {
          type: "Success",
          title: "Winner declared",
          message: `Address ${winner} has won the lottery ${
            parsedLotteryId + 1
          }!`,
        });
      });

      contract.on("LotteryFinished", (lotteryId, winner) => {
        let parsedLotteryId = parseInt(lotteryId);
        let message = `Lottery ${parsedLotteryId + 1} has finished! ${
          winner === ZERO_ADDRESS
            ? "There were not participants"
            : `Winner address is ${winner}`
        }`;

        setIsDeclaringWinner(false);
        updateLotteries();
        handleNewNotification(dispatch, {
          type: "Success",
          title: "Lottery finished",
          message,
        });
      });
    }
  }, [contract]);

  return (
    <div>
      <Head>
        <title>Lottery</title>
        <meta
          name="description"
          content="Your gambling time with your friends is just 1 click away!"
        />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <>
        <Presentation />
        {active ? (
          <>
            {appChainId === chainId && (
              <div className={styles.connected}>
                <Button
                  icon="plus"
                  text="Create lottery"
                  theme="primary"
                  type="button"
                  onClick={() => setIsModalOpen(true)}
                  loadingText="Creating lottery..."
                  isLoading={isCreatingLottery}
                  isFullWidth={true}
                />
                <LotteryModal
                  isModalOpen={isModalOpen}
                  setIsModalOpen={setIsModalOpen}
                  setIsCreatingLottery={setIsCreatingLottery}
                />
              </div>
            )}
            <Lotteries
              lotteries={lotteries}
              isBuyingTicket={isBuyingTicket}
              setIsBuyingTicket={setIsBuyingTicket}
              isDeclaringWinner={isDeclaringWinner}
              setIsDeclaringWinner={setIsDeclaringWinner}
            />
          </>
        ) : (
          <>
            <ConnectWallet />
            <div className={styles.imageContainer}>
              <Image src={presentationImg} width={500} height={500} />
            </div>
          </>
        )}
      </>
      <Footer />
    </div>
  );
}
