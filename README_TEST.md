# Referral System

## ReferralSystemBsc
### Main Prices
```
uint256[] public prices = [
    0,
    0.2 ether,
    0.3 ether,
    0.5 ether,
    1 ether,
    2 ether,
    3 ether,
    5 ether,
    10 ether,
    18 ether,
    30 ether,
    50 ether,
    100 ether,
    180 ether,
    300 ether,
    500 ether
];
```

### Test Prices
```
uint256[] public prices = [
    0,
    0.001 ether,
    0.002 ether,
    0.003 ether,
    0.004 ether,
    0.005 ether,
    0.006 ether,
    0.007 ether,
    0.008 ether,
    0.009 ether,
    0.010 ether,
    0.011 ether,
    0.012 ether,
    0.013 ether,
    0.014 ether,
    0.015 ether
];

```
uint256[] public binLevelRate = [
    0,
    600,
    600,
    700,
    700,
    700,
    800,
    800,
    900,
    900,
    1000,
    1000,
    1100,
    1100,
    1200,
    1200
];
```

### Constructor params
- `refLevelRate` - 15 levels:
```
[
[0, 0, 0, 0, 0, 0, 0, 0],
[200, 100, 0, 0, 0, 0, 0, 0],
[300, 200, 0, 0, 0, 0, 0, 0],
[400, 200, 100, 0, 0, 0, 0, 0],
[400, 300, 200, 0, 0, 0, 0, 0],
[500, 400, 200, 0, 0, 0, 0, 0],
[500, 400, 300, 100, 0, 0, 0, 0],
[600, 500, 300, 100, 0, 0, 0, 0],
[600, 500, 400, 200, 0, 0, 0, 0],
[700, 600, 400, 300, 100, 0, 0, 0],
[700, 600, 500, 300, 200, 0, 0, 0],
[800, 600, 500, 400, 200, 100, 0, 0],
[800, 700, 600, 500, 300, 100, 0, 0],
[900, 700, 600, 500, 300, 200, 100, 0],
[900, 800, 700, 500, 400, 300, 100, 0],
[1000, 800, 700, 500, 400, 300, 200, 100]
]
```
or
```
[[0,0,0,0,0,0,0,0],[200,100,0,0,0,0,0,0],[300,200,0,0,0,0,0,0],[400,200,100,0,0,0,0,0],[400,300,200,0,0,0,0,0],[500,400,200,0,0,0,0,0],[500,400,300,100,0,0,0,0],[600,500,300,100,0,0,0,0],[600,500,400,200,0,0,0,0],[700,600,400,300,100,0,0,0],[700,600,500,300,200,0,0,0],[800,600,500,400,200,100,0,0],[800,700,600,500,300,100,0,0],[900,700,600,500,300,200,100,0],[900,800,700,500,400,300,100,0],[1000,800,700,500,400,300,200,100]]
```


## ReferralSystemPolygon
### Test Prices
```
uint256[] public prices = [
    0,
    0.001 ether,
    0.002 ether,
    0.003 ether,
    0.004 ether,
    0.005 ether,
    0.006 ether,
    0.007 ether,
    0.008 ether,
    0.009 ether,
    0.010 ether,
    0.011 ether,
    0.012 ether,
    0.013 ether,
    0.014 ether,
    0.015 ether,
    0.016 ether
];

```
### Constructor params
- `refLevelRate` - 16 levels:
```
?
```
or
```
?
```




### Deploy
```
# deploy
gas	8173261 gas
transaction cost	7107183 gas 
execution cost	6716563 gas

# 1 buy 1,1 
gas	390475 gas
transaction cost	339543 gas

# 2 buy 1,1 
transaction cost	472091 gas 
execution cost	450379 gas

# 3 buy 1,1 
gas	562180 gas
transaction cost	488852 gas 
execution cost	467140 gas

# 4  buy 1,1 
gas	599968 gas
transaction cost	521711 gas 
execution cost	499999 gas 

# 5 buy 1,1 
gas	637693 gas
transaction cost	552293 gas 
execution cost	530581 gas

# 6 buy 1,1 
gas	672925 gas
transaction cost	585152 gas 
execution cost	563440 gas 

# buy 1,1 
gas	708095 gas
transaction cost	615734 gas 
execution cost	594022 gas

# 7 buy 1,1 
gas	743327 gas
transaction cost	646371 gas 
execution cost	624659 gas 

# 8 buy 1,1 
gas	778136 gas
transaction cost	676640 gas 
execution cost	654928 gas

# 9 buy 1,1 
gas	803635 gas
transaction cost	698813 gas 
execution cost	677101 gas 
803635-778136=25499

# 10 buy 1,1 
gas	829134 gas
transaction cost	718764 gas 
execution cost	697052 gas 
829134-803635=25499

# 11 buy 1,1 
gas	852141 gas
transaction cost	740992 gas 
execution cost	719280 gas

852141-829134=23007
не учтено много реф выплат из-за уровней


10000000/25000=400 высота
10000000/20000=500 высота это 10-11млн газа за транзакцию


в сети bsc комиссия 5 gwei (0,000000005)
Лимит газа на блок 10млн 
0,000000005 * 10000000 = 0.05 bnb (16,17 usd ) потенциальная максимальная комиссия за газ

```
