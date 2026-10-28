# clipOs

Gerenciador de histórico da área de transferência para macOS, na barra de menus. Guarda texto e imagens, abre com um atalho global e cola o item escolhido no app em foco.

## Recursos

- Histórico de texto e imagens (até 200 itens), com busca nos textos
- Atalho global configurável (padrão `⌘⇧C`)
- `↑`/`↓` navegam, `Enter` cola, `⌘1`–`⌘9` colam direto, `Esc` fecha
- Fixar e excluir itens (clique direito no item)
- Ignora conteúdo marcado como sensível (senhas de gerenciadores)
- Inicia junto com o Mac (configurável)

## Requisitos

- macOS 14 ou superior
- Swift 5.9+ (basta o Command Line Tools: `xcode-select --install`; não precisa do Xcode)

## Instalação

```sh
git clone https://github.com/AriHenrique/clipOs.git
cd clipOs
./build.sh --install
open ~/Applications/Clip.app
```

O script compila, monta o `Clip.app`, assina com assinatura ad-hoc e copia para `~/Applications`. Sem `--install`, o app fica só em `build/Clip.app`.

## Permissões (primeira execução)

1. **Acessibilidade**: necessária para colar automaticamente (o app envia `⌘V`). Ajustes do Sistema → Privacidade e Segurança → Acessibilidade → ative o **Clip**. Sem ela, o item é só copiado e você cola com `⌘V`.
2. **Barra de Menus** (macOS 26): se o ícone não aparecer, ative o Clip em Ajustes do Sistema → Barra de Menus.
3. **Itens de Login**: se o macOS pedir, aprove o Clip em Ajustes do Sistema → Geral → Itens de Login.

> A assinatura é ad-hoc, então a cada recompilação o macOS pode descartar a permissão de Acessibilidade. Remova e adicione o Clip de novo na lista.

## Uso

- `⌘⇧C` abre o histórico.
- Clique direito no ícone da barra de menus: **Ajustes…** (atalho global, iniciar com o Mac), **Limpar histórico** (mantém fixados), **Sair**.

## Dados

Histórico em `~/Library/Application Support/Clip/` (`history.json` e `images/`).

## Desinstalar

```sh
pkill -x Clip
rm -rf ~/Applications/Clip.app "$HOME/Library/Application Support/Clip"
```

Remova também o Clip da lista de Acessibilidade e de Itens de Login.
