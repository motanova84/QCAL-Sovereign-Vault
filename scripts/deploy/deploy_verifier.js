const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("==================================================");
    console.log("  Despliegue de QCALResonanceVerifier — PayGate");
    console.log("==================================================\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log(`[+] Cuenta desplegadora: ${deployer.address}`);

    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log(`[+] Balance disponible: ${hre.ethers.formatEther(balance)} ETH`);

    // 1. Configuración del Enclave Validador
    const enclaveSignerAddress = process.env.ENCLAVE_SIGNER_ADDRESS || deployer.address;
    console.log(`[+] Secure Enclave Signer configurado: ${enclaveSignerAddress}`);

    // 2. Compilación y fábrica
    console.log("\n[1/3] Compilando e instanciando QCALResonanceVerifier...");
    const VerifierFactory = await hre.ethers.getContractFactory("QCALResonanceVerifier");

    // 3. Despliegue
    console.log("[2/3] Enviando transacción de despliegue...");
    const verifier = await VerifierFactory.deploy(enclaveSignerAddress);
    await verifier.waitForDeployment();
    const verifierAddress = await verifier.getAddress();

    console.log(`\n[3/3] ✅ Contrato desplegado con éxito en: ${verifierAddress}`);

    // 4. Verificación de invariantes en cadena
    const targetFreq = await verifier.TARGET_FREQUENCY_MICRO_HZ();
    const minPsi = await verifier.MIN_PSI_COHERENCE();
    const configuredEnclave = await verifier.enclaveSigner();

    console.log("\n--- Parámetros del Invariante QCAL en Cadena ---");
    console.log(`  Frecuencia Objetivo  : ${Number(targetFreq) / 1e6} Hz (${targetFreq} μHz)`);
    console.log(`  Coherencia Mínima Ψ  : ${Number(minPsi) / 1e6} (Fixed Point 1e6: ${minPsi})`);
    console.log(`  Enclave Validador    : ${configuredEnclave}`);
    console.log("------------------------------------------------\n");

    // 5. Guardar artefacto de despliegue
    const deploymentData = {
        network: hre.network.name,
        chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
        contractAddress: verifierAddress,
        enclaveSigner: configuredEnclave,
        deployedAt: new Date().toISOString(),
        transactionHash: verifier.deploymentTransaction().hash
    };

    const deploymentsDir = path.join(__dirname, "../deployments");
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const filePath = path.join(deploymentsDir, `${hre.network.name}_verifier.json`);
    fs.writeFileSync(filePath, JSON.stringify(deploymentData, null, 2));
    console.log(`[+] Metadatos guardados en: ${filePath}`);

    console.log("\n∴𓂀Ω∞³Φ · DESPLIEGUE COMPLETO Y ANCLADO");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n[!] Error durante el despliegue:", error);
        process.exit(1);
    });
