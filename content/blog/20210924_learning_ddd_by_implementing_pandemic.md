---
title: "Learning DDD by making Pandemic"
date: 2021-09-24T16:40:58+10:00
draft: false
summary: "Learning the lower-level details of domain-drive design, through implementing the Pandemic board game"
tags:
- DDD
- csharp
---

Join me on my quest to learn some domain-driven design (DDD) while making a
board game. This is my longest post yet, so I've included a table of contents
for your convenience :)

If you want to skip straight to the action, see [Let's just start]({{< ref
"#lets_start" >}})

# Contents
{{< toc >}}


-------------------------------------------------------------------
# Introduction
I have tried a number of times to implement the board game
[Pandemic](https://en.wikipedia.org/wiki/Pandemic_%28board_game%29), so that I
could set AI upon it. Each attempt was a failure, due to the complexity of the
game rules causing my code to turn into a complex ball of mud. Recently I was
inspired to try again, after having the idea that [domain-driven design
(DDD)](https://en.wikipedia.org/wiki/Domain-driven_design) may help me deal with
the complexity.

I had known of domain-driven design for years, but had never looked closely into
it. I had a very basic understanding of some DDD concepts, such as breaking
complex systems into 'bounded contexts', and using 'anti corruption layers' to
keep the domain model clean, but that was about it. It was only after starting
work on this post that I realised that DDD covers a huge landscape of software
development, including many low-level concepts that can be applied even within
small applications, such as board games!

In this post I will focus on some of these low-level 'tactical' aspects of DDD,
and implementing them in C#. Note that these low level details are only a small
part of DDD as originally described by Eric Evans in his now famous ['Blue
book'](https://www.goodreads.com/book/show/179133.Domain_Driven_Design). See the
[references and further reading]({{< ref "#references" >}}) section at the end of this post for more
resources on DDD.

A disclaimer before I go on: I haven't read Eric Evans's book. It has a
reputation for being long and boring, and I was keen to get started. Most of the
information in this post has come from various online sources, which are linked
throughout and at the end of this post.


# It's been done
A quick search revealed that someone else had already tried DDD on another board
game. In [DDD in action: Armadora - The board
game](https://dev.to/thomasferro/ddd-in-action-armadora-the-board-game-2o07),
Thomas Ferro describes how he implemented a simple board game using DDD concepts
and event sourcing. This post, accompanied by [Summary of a four days DDD
training](https://dev.to/thomasferro/summary-of-a-four-days-ddd-training-5a3c)
were just the crash course I needed to see how the concepts could be applied for
someone new to DDD. However, the simplicity of the Armadora game left me
wondering how more complex games like pandemic would be implemented.

I also found what looks to be a [complete implementation of
Pandemic](https://github.com/alexzherdev/pandemic), using React & Redux. You can
[play it online here](https://epidemic.netlify.app). Have a go, it's really
well done! I don't think DDD was an influence on this implementation, however it
was useful to have as a reference.


# Applying DDD tactics to Pandemic
My stumbling point in the past has been the complex game rules of Pandemic.
Certain player actions result in chain reactions of side effects. For example,
if you pick up an 'epidemic' card, a series of events can occur, based on
certain conditions:

<figure>
  <img src="/blog/20210924_learning_ddd/end_turn_with_epidemic_flow.png"
  alt=""
  width="773"
  loading="lazy" />
  <figcaption>Some game rules at the end of a player's turn</figcaption>
</figure>

The flowchart above does not even show all the game rules: there are checks for
game end, outbreaks can occur when cities are infected, event cards may be
played, and more!

One way DDD attempts to simplify complex domains is by breaking down complex
processes such as the one above into sequences of [domain events]({{< ref
"#domain_event" >}}). A domain event represents any change to the system. Events
are emitted as a result of commands issued within the system. Using the above
flowchart as an example, the player issues the 'do action' command. If it was
the player's last action, then two 'card drawn' events could be emitted. If
either of those cards were an epidemic card, then more epidemic events are
emitted.


## How to handle events that trigger other events
Breaking down the complex rules into small commands and events sounds like a
good way to keep the underlying software parts small and manageable. However,
I'm worried about managing and debugging the explosion of events that may occur.
Are events supposed to trigger other events in DDD?

From what I've read so far, a domain model in DDD is made up of [aggregates]({{< ref
"#aggregate" >}}),
which are always internally consistent. Multiple aggregates are brought into a
consistent state asynchronously, by the publishing of domain events. So in
theory, an endless sequence of domain events could be emitted as multiple
aggregates react to events sent by other aggregates. Presumably this is an
undesirable condition to find your software in.
[Armadora](https://dev.to/thomasferro/ddd-in-action-armadora-the-board-game-2o07)
uses a single aggregate to represent the current state of the game, thus
removing the complication of keeping multiple aggregates in sync. Additionally,
events do not trigger any other events. Commands may emit multiple events, and
I found one example of a [command calling another command](https://github.com/ThomasFerro/armadora/blob/84db3e24a57aaccad72953ae3ab484f410663bec/server/game/command/pass_turn.go#L38).
This is what I will do for now.


## Let's just start {#lets_start}
OK, I think I have got enough to start. I'll figure out the rest as I go. To
start, I will use:

- one aggregate to represent the current state of the game
- immutable data, including aggregates and entities. This does not follow DDD,
  but will be useful for AI algorithms that will need to search and keep track
  of many game states.
- [event sourcing]({{< ref "#event_sourcing" >}}), mainly as I've never used it
  before, and it appears to remove some of the hassle of state management, and
  keep the code more functional (as in functional programming)
- C#, as I'm most familiar with it, and I would like to get more experience with
  some of its newer functional capabilities (mainly records and pattern
  matching)

My goal for now is to implement enough game rules to be able to play a game to
completion. I will pick the simplest rules to start with. Once that's done, I
can start adding rules incrementally, until the whole game is implemented.

Since an aggregate is responsible for maintaining its own consistency, I think I
need to implement all command handlers in the aggregate. I am a little worried
about how big the aggregate is going to be, but I think the process of breaking
down the rules into discrete commands and events will help keep the
corresponding code manageable.


## Baby steps
Here's my initial aggregate:

```cs
// My one aggregate - the state of the game
public record PandemicGame
{
    public Difficulty Difficulty { get; init; }

    // Create the game aggregate from an event log
    public static PandemicGame FromEvents(IEnumerable<IEvent> events) =>
        events.Aggregate(new PandemicGame(), Apply);

    // This is the 'set difficulty' command. Commands yield events.
    // Since I am using event sourcing, there is no need to mutate
    // the aggregate within the commands. The current state of the
    // aggregate can be built on demand from the event log.
    public static IEnumerable<IEvent> SetDifficulty(
        List<IEvent> log, Difficulty difficulty)
    {
        yield return new DifficultySet(difficulty);
    }

    // Modify the aggregate with an event. Returns an updated copy
    // of the current aggregate.
    public static PandemicGame Apply(
        PandemicGame pandemicGame, IEvent @event)
    {
        return @event switch
        {
            DifficultySet d => pandemicGame with {Difficulty = d.Difficulty},
            _ => throw new ArgumentOutOfRangeException(nameof(@event), @event, null)
        };
    }
}
```

## First complex process
After a few hours of coding simple events, I have reached an interesting point.
I need to implement the sequence of events that occur when a player does their
last action. Here's what my current `DriveOrFerryPlayer` command looks like:

```cs
public static IEnumerable<IEvent> DriveOrFerryPlayer(List<IEvent> log, Role role, string city)
{
    if (!Board.IsCity(city)) throw new InvalidActionException($"Invalid city '{city}'");

    var state = FromEvents(log);
    var player = state.PlayerByRole(role);
    if (!Board.IsAdjacent(player.Location, city))
    {
        throw new InvalidActionException(
            $"Invalid drive/ferry to non-adjacent city: {player.Location} to {city}");
    }

    yield return new PlayerMoved(role, city);

    // todo: handle when this was the player's last action
}
```


To make things easier, I won't consider all the rules as shown in the earlier
flowchart. Here's a simplified version:

<figure>
  <img src="/blog/20210924_learning_ddd/end_turn_flow_simple.png"
  alt=""
  width="250"
  loading="lazy" />
  <figcaption>A simplified 'end of player turn' flow</figcaption>
</figure>

I did a mini [event storming]({{< ref "#event_storming" >}}) to determine
commands and events involved in the above flowchart. There's only one aggregate
(the game), so I've omitted it from the image. Commands with no human player
next to them are issued by the 'game'.

<figure>
  <img src="/blog/20210924_learning_ddd/end_turn_flow_simple_event_storm.png"
  alt=""
  width="492"
  loading="lazy" />
  <figcaption>Event storming a simple 'end of player turn' flow.
  Commands are blue, events are orange.</figcaption>
</figure>


Here's the `DriveOrFerryPlayer` command after adding the above events:

```cs
public static IEnumerable<IEvent> DriveOrFerryPlayer(
    List<IEvent> log, Role role, string city)
{
    if (!Board.IsCity(city))
        throw new InvalidActionException($"Invalid city '{city}'");

    var state = FromEvents(log);
    var player = state.PlayerByRole(role);

    if (player.ActionsRemaining == 0)
        throw new GameRuleViolatedException(
            $"Action not allowed: Player {role} has no actions remaining");

    if (!Board.IsAdjacent(player.Location, city))
    {
        throw new InvalidActionException(
            $"Invalid drive/ferry to non-adjacent city: {player.Location} to {city}");
    }

    yield return new PlayerMoved(role, city);

    if (player.ActionsRemaining == 1)
    {
        // todo: pick up cards from player draw pile here
        yield return new PlayerCardPickedUp(role, new PlayerCard("Atlanta"));
        yield return new PlayerCardPickedUp(role, new PlayerCard("Atlanta"));
        foreach (var @event in InfectCity(log))
        {
            yield return @event;
        }
        foreach (var @event in InfectCity(log))
        {
            yield return @event;
        }
    }
}

private static IEnumerable<IEvent> InfectCity(List<IEvent> log)
{
    var state = FromEvents(log);
    var infectionCard = state.InfectionDrawPile.Last();
    yield return new InfectionCardDrawn(infectionCard.City);
    yield return new CubeAddedToCity(infectionCard.City);
}
```

It's not as bad as I thought it would be! I separated out the private
`InfectCity` command for convenience. It's not a command a player can issue, but
makes the `DriveOrFerryPlayer` code easier to understand from a domain
perspective. The aggregate is getting large (200 lines so far), but all the code
seems to belong to it.


# Moving away from event sourcing
I have decided to stop using event sourcing, mainly because it is making testing
difficult. I want to be able to set up a near-end game state to be able to
assert game ending scenarios. With my current implementation, the only way to
create a game aggregate is from an event log. Although this ensures the
aggregate is in a valid state, it makes setting up these test scenarios
laborious, and I will need to constantly tweak the test setup as I add more game
rules, to ensure that the events leading to the game-ending state are valid.

Instead of rebuilding the game aggregate from the event log, I will make the
commands instance methods of the aggregate. This way, commands immediately have
access to the current game state. Having an event log is useful for debugging
purposes, so I will keep emitting events for all modifications of the game
state. Being able to create the game aggregate in an invalid state is a hazard,
but for my purposes is very handy for testing. I wonder if there's a way to
disable the usage of dangerous constructors in production code? I'll put that on
the 'to do later' pile.

Here's what I have come up with. There are many command and event handlers on
the aggregate, but they are all following an emerging pattern:

```cs
// Command handlers are public methods on the aggregate. They take parameters
// relevant to the command, and return a new game aggregate and a collection of
// events that occurred as a result of the command.
public (PandemicGame, ICollection<IEvent>) Command(arg1, arg2, ...) {}

// Event handlers are private static methods (pure functions) that apply a
// single event to the given aggregate, returning a resultant aggregate.
private static PandemicGame HandleEvent(PandemicGame game, IEvent @event) {}

// 'Internal command handlers' are convenient ways to break down larger
// commands, that involve many events and conditional logic.
private static PandemicGame InternalCommand(
    PandemicGame currentState,
    ICollection<IEvent> events) {}
```

Let's see it in action. This is the current state of my `DriveOrFerryPlayer`
command handler, which needs to perform a number of actions when the player has
performed the last action for their turn:

```cs
public (PandemicGame, ICollection<IEvent>) DriveOrFerryPlayer(Role role, string city)
{
    if (!Board.IsCity(city))
        throw new InvalidActionException($"Invalid city '{city}'");

    var player = PlayerByRole(role);

    if (player.ActionsRemaining == 0)
        throw new GameRuleViolatedException(
            $"Action not allowed: Player {role} has no actions remaining");

    if (!Board.IsAdjacent(player.Location, city))
    {
        throw new InvalidActionException(
            $"Invalid drive/ferry to non-adjacent city: {player.Location} to {city}");
    }

    var (currentState, events) = ApplyEvents(new PlayerMoved(role, city));

    if (currentState.CurrentPlayer.ActionsRemaining == 0)
        currentState = DoStuffAfterActions(currentState, events);

    return (currentState, events);
}

private static PandemicGame DoStuffAfterActions(
    PandemicGame currentState,
    ICollection<IEvent> events)
{
    currentState = PickUpCard(currentState, events);
    currentState = PickUpCard(currentState, events);

    currentState = InfectCity(currentState, events);
    currentState = InfectCity(currentState, events);

    return currentState;
}
```

`DriveOrFerryPlayer` is going to continue to grow as I add more game logic. I'm
a little worried about that. There are more DDD concepts that I may be able to
use here: 'sagas' or 'process managers', and 'services'. I don't know if these
are appropriate, as I believe they are intended to coordinate behaviour between
aggregates. Since this post is getting rather long, I'll leave this for later.

I also don't really like the difference in method signatures between the public
and private command handlers.

> Side note: I'm glad I chose to use records with immutable collections for my
> data types. Immutable collection methods return updated copies of the
> collections, as does the `with` expression for C# records. This makes it very
> easy to create new states based on events. For example:
>
> ```cs
> private static PandemicGame ApplyPlayerCardDiscarded(
>   PandemicGame game,
>   PlayerCardDiscarded discarded)
> {
>     var discardedCard = game
>       .CurrentPlayer
>       .Hand
>       .Single(c => c.City == discarded.City);
>
>     return game with
>     {
>         Players = game
>           .Players
>           .Replace(game.CurrentPlayer, game.CurrentPlayer with
>           {
>               Hand = game
>                 .CurrentPlayer
>                 .Hand
>                 .Remove(discardedCard)
>           })
>     };
> }
> ```


# Wrapping up this post
Despite the above concerns, I am confident that I can incrementally add game
rules until I have a full game implementation. The biggest benefit I have got
from DDD so far is a way of breaking down the game rules into fine grained
commands and events that are easy to reason about and implement.


-------------------------------------------------------------------
# Appendix: DDD concepts used in this post
## Domain
The domain is the problem to be solved, and its surrounding context. In my case,
the domain is the Pandemic board game. The people working in the domain should
have a shared understanding of the domain model. It should be described in
non-technical, jargon-free language that everyone can understand. This
'ubiquitous language' (another DDD term) should be used when discussing the
domain model. Since I'm the only one working in the domain, the Pandemic rule
book will be my domain expert, and I will use language within the rules when
naming the software objects I create to build the game.

## Domain event {#domain_event}
A domain event can be any event of interest within the domain. An event is a
result of some action within the domain. For example, in Pandemic, when a player
moves from one city to another, this can be described as a 'player moved' event.
The event contains information about what occurred, eg. which player moved, and
which cities they moved from and to.

## Event storming {#event_storming}
Typically, event storming is a session where domain, product, and technical
experts come together to explore and model a domain, starting by brainstorming
events that can occur within the domain.

In my case, these were little 'pen & paper' sessions where I mapped out a
sequence of game events and subsequent side effects.

- [Wikipedia: Event storming](https://en.wikipedia.org/wiki/Event_storming)

## Aggregate {#aggregate}
An aggregate is a collection of objects that can be treated as an individual
unit. An example could be an online shopping cart, which may contain multiple
products.

More importantly, an aggregate forms a 'consistency boundary'. The aggregate
ensures that it remains internally consistent. For example, if your domain
contains a rule that a + b = c, then a, b, and c should be within the same
aggregate. The aggregate is responsible for making sure that whenever a or b are
modified, c is updated.

Aggregates process commands, which potentially modify their state. Domain events
can be emitted as a result of these commands. The rest of the domain can listen
for these events and respond to them accordingly, keeping the domain consistent
with as aggregates change.

- [Vaughn Vernon: modelling a single aggregate (pdf)](https://www.dddcommunity.org/wp-content/uploads/files/pdf_articles/Vernon_2011_1.pdf)

## Event sourcing {#event_sourcing}
Not necessarily a part of DDD, however it can be a good fit. The idea is that
application state is stored in an append-only log of events. If the state of the
application at a point in time is needed, it can be built from the log of
events.


-------------------------------------------------------------------
# References {#references}
- [Pandemic](https://en.wikipedia.org/wiki/Pandemic_%28board_game%29)
- [Pandemic rules](https://www.ultraboardgames.com/pandemic/game-rules.php)
- [Wikipedia: DDD](https://en.wikipedia.org/wiki/Domain-driven_design)
- [DDD in action: Armadora - The board game](https://dev.to/thomasferro/ddd-in-action-armadora-the-board-game-2o07).
    - [Armadora code](https://github.com/ThomasFerro/armadora)
- [Thomas Fero: Summary of a four days DDD training](https://dev.to/thomasferro/summary-of-a-four-days-ddd-training-5a3c)
- [Epidemic](https://epidemic.netlify.app)
    - an online Pandemic clone, built with React & Redux
    - [Epidemic source code](https://github.com/alexzherdev/pandemic)
- [Wikipedia: Event storming](https://en.wikipedia.org/wiki/Event_storming)
- domain events
    - [MSDN: Domain events: design and implementation](https://docs.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
- aggregates
    - [Vaughn Vernon: modelling a single aggregate (pdf)](https://www.dddcommunity.org/wp-content/uploads/files/pdf_articles/Vernon_2011_1.pdf)

# Further reading / work
Some resources that I haven't investigated much / at all:

- The original DDD book ('The Blue Book') by Eric Evans: [Domain-Driven
  Design](https://www.goodreads.com/book/show/179133.Domain_Driven_Design)
    - Comes highly recommended as the authoritative source for DDD, however has
      a reputation for being overly verbose and boring.
- [Implementing Domain Driven Design - Vaughn
  Vernon](https://www.amazon.com/Implementing-Domain-Driven-Design-Vaughn-Vernon/dp/0321834577)
    - Apparently a shorter and more practical book than the original
- [boardgame.io](https://boardgame.io/)
    - a turn-based game framework where users provide their game object &
      commands, which could be considered a DDD aggregate & commands.
    - the framework provides a `ctx` object which contains extra data about the
      game. It gets updated via events emitted by commands, much like in DDD.
