# reusable-workflows

Repositório de workflows reutilizáveis para GitHub Actions, agnósticos à tecnologia do projeto consumidor.

## Estrutura

```
reusable-workflows/
├── .github/
│   ├── templates/
│   │   ├── pull-request.md                 # Template de pull request para reutilização
│   │   ├── summary-quality.md              # Template do Summary do workflow de qualidade
│   │   └── summary-conventional-commits.md # Template com instruções de fix para commits inválidos
│   └── workflows/
│       ├── ci-quality.yml                  # Qualidade: stack, testes, cobertura, commits
│       ├── cd-pull-request.yml             # (em breve)
│       └── cd-semantic-release.yml         # (em breve)
└── scripts/
    ├── plugins/
    │   ├── node/
    │   │   ├── test.sh               # Executa testes (npm test)
    │   │   ├── coverage.sh           # Calcula cobertura (Jest / c8)
    │   │   ├── publish.sh            # Publica no NPM / GitHub Packages
    │   │   └── gen-release-config.sh # Gera .releaserc.json específico para Node
    │   ├── php/
    │   │   ├── test.sh            # PHPUnit
    │   │   └── coverage.sh        # PHPUnit --coverage-text
    │   ├── python/
    │   │   ├── test.sh            # pytest
    │   │   └── coverage.sh        # pytest-cov
    │   ├── go/
    │   │   ├── test.sh            # go test ./...
    │   │   └── coverage.sh        # go tool cover
    │   └── dotnet/
    │       ├── test.sh            # dotnet test
    │       └── coverage.sh        # XPlat Code Coverage → Cobertura XML
    └── shared/
        ├── detect-stack.sh        # Auto-detecta a stack do projeto
        ├── shell-helpers.sh       # Funções utilitárias (log, output, JSON)
        ├── validate-commits.mjs   # Valida Conventional Commits (commitlint)
        └── semantic-release/
            └── .releaserc.json    # Config base do semantic-release
```

## Contrato de Output dos Scripts

Todos os scripts de plugin seguem o mesmo contrato de saída:

| Mecanismo | Descrição |
|---|---|
| `GITHUB_OUTPUT` | Variáveis exportadas para uso no step/job seguinte |
| `/tmp/qa-{script}-output.json` | Arquivo JSON com os resultados completos |
| `output_file` (GITHUB_OUTPUT) | Caminho do arquivo JSON gerado |

- Scripts de teste exportam: `has_tests`, `tests_passed`, `output_file`
- Scripts de cobertura exportam: `coverage_pct`, `coverage_tool`, `output_file`
- `detect-stack.sh` exporta: `stack`, `stack_source`, `output_file`
- `validate-commits.mjs` exporta: `commits_valid`, `total_count`, `invalid_count`, `output_file`

## ci-quality.yml

### Como usar

```yaml
jobs:
  quality:
    uses: your-org/reusable-workflows/.github/workflows/ci-quality.yml@main
    with:
      stack: "auto"                  # ou: node | php | dotnet | python | go
      project_path: "."
      coverage_min: 80
      coverage_strict_mode: "block"  # info | block | decrease
      commit_validation_mode: "block" # info | block
    secrets:
      GH_TOKEN: ${{ secrets.GH_TOKEN }} # necessário apenas se project_private: true
```

### Inputs

| Input | Tipo | Default | Descrição |
|---|---|---|---|
| `stack` | string | `auto` | Stack do projeto. `auto` ativa detecção automática |
| `project_path` | string | `.` | Caminho relativo ao código-fonte |
| `project_private` | boolean | `false` | Se `true`, usa `GH_TOKEN` no checkout |
| `coverage_base_branch` | string | `main` | Branch base para comparação no modo `decrease` |
| `coverage_command` | string | — | Comando customizado de cobertura |
| `coverage_min` | number | `80` | Cobertura mínima (%) para modo `block` |
| `coverage_strict_mode` | string | `info` | `info` \| `block` \| `decrease` |
| `commit_validation_mode` | string | `info` | `info` \| `block` |

### Modos de cobertura

| Modo | Comportamento |
|---|---|
| `info` | Apenas reporta. Nunca bloqueia. |
| `block` | Falha se cobertura < `coverage_min` |
| `decrease` | Falha se cobertura for menor que a da branch base. Se não houver artefato anterior, trata como `info`. |

### Modos de commit

| Modo | Comportamento |
|---|---|
| `info` | Apenas reporta commits inválidos no Summary. |
| `block` | Falha o pipeline e exibe instruções de correção no Summary. |

### Contrato de saída

O workflow expõe o output `contract` com o seguinte schema JSON:

```json
{
  "schema_version": "1.0.0",
  "generated_at": "ISO8601",
  "run": { "id", "number", "ref", "sha", "actor", "event", "repository" },
  "stack": { "detected", "source" },
  "tests": { "found", "passed" },
  "coverage": { "percentage", "base_percentage", "minimum", "tool", "mode", "status", "message" },
  "commits": { "valid", "total_count", "invalid_count", "mode" },
  "overall_status": "pass | fail"
}
```

O contrato também é salvo como artefato `quality-contract-{branch}` com 90 dias de retenção.

## Adicionando suporte a uma nova stack

1. Crie `scripts/plugins/<stack>/test.sh`
2. Crie `scripts/plugins/<stack>/coverage.sh`
3. Siga o contrato de output: exporte `GITHUB_OUTPUT` + gere `/tmp/qa-{script}-output.json`
4. Use `source "../../shared/shell-helpers.sh"` para funções utilitárias
5. A detecção automática em `detect-stack.sh` pode precisar de um novo seletor de arquivo

Não é necessário alterar nenhum workflow YAML — o `ci-quality.yml` chama dinamicamente `scripts/plugins/<stack>/test.sh`.