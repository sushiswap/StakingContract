
# Allow retroactive subscription

## Idea: store a timestamp of a last liquidity event to allow users to retroactevely subscribe to an incentive

- Modify ```struct UserStake``` to include a timstamp of the last liquidity event.
- Remove ```liquidityStaked``` from ```struct Incentive```. Instead, assume everyone is staked and use the staking contract's balance as the staked liquidity amount.
- Redisign the reward calculation: accumulate a (time delta × liquidity staked) value for an incentive. A users reward is then proportional to (user's stake duration × user's liquidity) / accumulator value.
- Alternatively figure out a different reward calculation that solves cons (1) & (2).

Pros:

- User's don't have to manually subscribe when a new incentive arrives.

Cons:

- Rewards are relative based on the total ratio. An example to illustrate the negative effect of this: If only two users stake, one with a dust amount and the other with a regular sized amount but only for the second half of the incentive duration, they will still get the majority of rewards instead of the 50% as expected, since the total ratio will be skewed to the second user. Before the second user stakes the first user can claim half of the rewards, if they don't their reward will get diluted to 0.
- Similarly, updating an incentive reward amount changes (unclaimed) user rewards. (Since a share of the total reward belongs to a user, not a specific amount).
- Incentives will have a lower apy on average.
- Some part of the incentive rewards will be burned if users (us)stake a token and don't claim the accrued rewards. Since users are unknowingly subscribed this would be a more common occurance that if users have to manually subscribe.
- Significant refactor from the current method, invalidates current audit.
- Using balanceOf to get the staked liqudity assumes no staked token is used a reward for an incentive.
