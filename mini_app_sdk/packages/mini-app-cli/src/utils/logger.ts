import pc from 'picocolors';

export const logger = {
  info: (msg: string) => console.log(`${pc.cyan('ℹ')} ${pc.bold(msg)}`),
  success: (msg: string) => console.log(`${pc.green('✔')} ${pc.bold(pc.green(msg))}`),
  warn: (msg: string) => console.log(`${pc.yellow('⚠')} ${pc.yellow(msg)}`),
  error: (msg: string, err?: any) => {
    console.error(`${pc.red('✖')} ${pc.bold(pc.red(msg))}`);
    if (err) console.error(err);
  },
  title: (msg: string) => {
    console.log(`\n${pc.bgCyan(pc.black(' SUPERAPP MINI APP CLI '))} ${pc.bold(msg)}\n`);
  },
  step: (step: number, total: number, msg: string) => {
    console.log(`${pc.dim(`[${step}/${total}]`)} ${msg}`);
  },
};
