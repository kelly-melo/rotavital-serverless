# Rota Vital · Atividade individual 1 (Serverless)

Função serverless que recebe uma requisição do Rota Vital (POST /guias) e devolve a guia de transporte de bolsas de sangue.

- **Disciplina:** Infraestrutura de Software · ADS · CESAR School · 2026.2
- **Estudante:** Kelly Priscilla de Siqueira Melo
- **Caminho escolhido:** A (AWS SAM CLI local, Python 3.12), executado no GitHub Codespaces porque o computador que eu uso não permite instalar programas.
- **Vídeo (até 3 min):** https://youtu.be/W1fCnxdwmpc

## Como rodar

Pré-requisitos: Docker, AWS SAM CLI e Python 3.12 (no Codespaces: `pip install aws-sam-cli`).

```bash
sam build
sam local invoke -e events/pedido.json          # invocação com evento (rodei 2x)
sam local start-api                             # gatilho HTTP
bash experimentos.sh                            # chamadas curl (em outro terminal)
sam local start-api --warm-containers LAZY      # reaproveitando o container
```

Para o Passo 5, o `Timeout` do `template.yaml` começou em 3 s e depois foi para 10 s (com `sam build` entre eles). O evento `events/demorar.json` e o último curl do `experimentos.sh` usam `demorar: true`.

## Resultados medidos

| Experimento | Resultado |
|---|---|
| `sam local invoke` #1 | Init 0,03 ms · Duration 45,22 ms · Billed 46 ms · contador 1 |
| `sam local invoke` #2 | Init 0,04 ms · Duration 44,26 ms · Billed 45 ms · contador 1 |
| `start-api` sem warm (3 chamadas) | contador 1, 1, 1 (0,81 s, 0,60 s e 0,65 s no curl) |
| `start-api --warm-containers LAZY` | contador 1, 2, 3 · Duration de ~1 ms nas chamadas reaproveitadas |
| `demorar=true`, Timeout 3 s | `Function 'GuiaFunction' timed out after 3 seconds`, Duration 3000 ms, HTTP 502 em 3,93 s |
| `demorar=true`, Timeout 10 s | HTTP 201 depois de ~5 s |
| Sem `requisicaoId` | HTTP 400 |

Evidências na pasta `evidencias/`: `invoke-1.png`, `invoke-2.png`, `start-api-sem-warm.png`, `start-api-warm.png`, `start-api-warm-servidor.png`, `timeout-3s.png`, `timeout-10s.png`.

## Respostas

**1. Por que a primeira invocação demorou mais que a segunda? O que acontece na fase de Init?**
Na teoria, a primeira invocação precisa criar o ambiente de execução (cold start): o serviço prepara o container, carrega o código, inicia o runtime Python e executa o código que está fora do handler, como os `import` e o `contador = 0`. Isso é a fase de Init. Depois vem a fase de Invoke, que roda o handler. Se o ambiente for reaproveitado, o Init não se repete e só o Invoke acontece.
Na prática, no `sam local invoke` os dois tempos ficaram praticamente iguais (45,22 ms e 44,26 ms) e o contador foi 1 nas duas, porque o comando sobe um container novo a cada execução, então as duas foram "frias". A diferença apareceu com `--warm-containers`: as chamadas com o container já em execução levaram cerca de 1 ms (Billed 2 ms), contra ~45 ms com container novo.

**2. O que o campo `invocacaoNesteAmbiente` mostrou com e sem `--warm-containers`? O que isso diz sobre guardar estado numa variável global?**
Sem `--warm-containers`, mostrou 1, 1, 1: cada requisição teve um container novo, e a variável global voltou a zero. Com `--warm-containers LAZY`, mostrou 1, 2, 3: o container foi mantido e o contador acumulou. Isso mostra que a variável global só sobrevive se o ambiente for reaproveitado, e isso não é garantido: a nuvem pode encerrar o ambiente a qualquer hora, e várias requisições ao mesmo tempo usam ambientes diferentes, cada um com seu contador. Por isso dados importantes (estoque de bolsas, status de requisições) devem ficar num serviço externo, como um banco de dados. A variável global só serve como cache que pode ser perdido sem problema.

**3. O que aconteceu com `demorar = true`? Qual é o tempo máximo de uma execução no Lambda e o que fazer com um trabalho mais longo?**
A função dorme 5 s, mas o Timeout do template era 3 s. A plataforma interrompeu a execução (`Function 'GuiaFunction' timed out after 3 seconds`, Duration 3000 ms) e o cliente recebeu HTTP 502 `Internal server error`. Ao aumentar o Timeout para 10 s e rodar `sam build` de novo, a função terminou e devolveu 201 depois de uns 5 s. O tempo máximo de uma execução no Lambda é de 15 minutos (900 s). Trabalhos mais longos devem ser divididos em etapas menores (por exemplo, com Step Functions ou uma fila SQS) ou rodar em um serviço sem esse limite, como containers (ECS/Fargate) ou AWS Batch.

**4. Custo de 1 milhão de execuções com 128 MB e 100 ms (us-east-1)**
- Requisições: 1.000.000 × US$ 0,20 / 1.000.000 = US$ 0,20
- Computação: 128 MB = 0,125 GB; 0,125 GB × 0,1 s = 0,0125 GB-s por execução; × 1.000.000 = 12.500 GB-s; × US$ 0,0000166667 = US$ 0,2083
- **Total ≈ US$ 0,41** (sem contar a faixa gratuita, que cobriria isso por completo).

**5. Em que parte do Rota Vital uma função assim faria sentido, e em qual não faria?**
Faz sentido em tarefas curtas, sem estado e acionadas por evento ou com demanda irregular, como gerar a guia de transporte quando uma requisição é aprovada, validar os dados de um pedido ou notificar o hospital quando uma bolsa muda de status. Paga-se só pelo que se usa e escala sozinho. Não faz sentido onde é preciso manter conexão ou estado, como no rastreamento em tempo real do veículo, nem para guardar o estoque de bolsas (isso é papel do banco de dados). Também exige cuidado no caminho crítico de uma emergência, onde o cold start pode atrasar a resposta, e em processos que passem de 15 minutos.

## Uso de IA

- **Ferramenta:** Claude (Anthropic).
- **Finalidade:** montar o esqueleto do projeto e um rascunho do README, e me ajudar a entender erros durante a execução.
- **Como validei:** Executei todo o projeto eu mesma no GitHub Codespaces, com Docker e AWS SAM CLI. Rodei `sam build` e `sam local invoke` duas vezes e conferi as saídas e os tempos (Init Duration e Duration). Subi a API com `sam local start-api` e fiz as chamadas com curl, observando o campo `invocacaoNesteAmbiente` com e sem `--warm-containers` (1, 1, 1 contra 1, 2, 3). Provoquei o erro de tempo limite com `demorar: true` e `Timeout: 3`, vi a mensagem `timed out after 3 seconds` no terminal do servidor e o HTTP 502 no curl, e depois aumentei o Timeout para 10, rodei `sam build` de novo e a função devolveu 201. Todas as respostas do README foram escritas a partir dos números e das saídas que eu mesma obtive, que estão nos prints da pasta `evidencias/`. Quando a execução deu erro (arquivos que não subiram para o repositório e o ambiente do Codespaces), usei a IA para entender a mensagem de erro e testei a correção rodando o comando de novo.
