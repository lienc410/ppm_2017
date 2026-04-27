##################### Chapter 5 ###########################
import random

a = [random.randint(1,20) for i in range(5)]

for i in a:
    if i > 5:
        print("big")
    else:
        print("small")
        
        
##################### Chapter 8 ###########################

class BankAccount(object):
    
    def __init__(self, name, balance):
        self.__name = name
        if balance >= 0:
            self.__balance = balance  
        else:
            balance = 0   
        print(self.__name, self.__balance)
        
    def deposit(self, balance):
        if balance >= 0:
            self.__balance += balance 
        print(self.__name, self.__balance)
        
    def withdraw(self, balance):
        if balance >= 0:
            self.__balance -= balance 
        print(self.__name, self.__balance)
    
    def RemainingBalance(self):
        print(self.__name, self.__balance)
        
    def Transfer(self, targetAcc, amount):
        if id(targetAcc) > 0:
            if amount > 0:
                self.withdraw(amount)
                targetAcc.deposit(amount)
        else:
            print("No account avaible for name:", targetAcc)
            
            
class CreditCardAccount(BankAccount):
    
#    def __init__(self, name, balance, limit):
#        BankAccount.__name = name
#        if balance >= 0:
#            BankAccount.__balance = balance  
#        else:
#            BankAccount.__balance = 0   
#        
#        if limit >= 0:
#            self.__creditLimit = limit  
#        else:
#            self.__creditLimit = 0   
#        print(self.__name, self.__balance, self.__creditLimit)        
    def setCreditLimit(self, limit):
        if limit >= 0:
            self.__creditLimit = limit  
        else:
            self.__creditLimit = 0   
        print(self.__name, self.__balance, self.__creditLimit)
        
    def withdraw(self, balance):
        if self.__balance - balance < -self.__creditLimit:
            print("Exceed credit limit")
        else:
            self.__balance = self.__balance - balance
            print(self.__name, self.__balance)


            
SamAcc = BankAccount("Sam", 1000)
SamAcc.deposit(500)
SamAcc.withdraw(1200)
SamAcc.RemainingBalance()

JohnAcc = BankAccount("John", 3000)
JohnAcc.Transfer(SamAcc, 1000)

SamCredit = CreditCardAccount("Sam", 1000)
SamCredit.setCreditLimit(1000)
SamCredit.withdraw(700)
SamCredit.withdraw(1500)
SamCredit.RemainingBalance()

################## Chapter 9 ###############################

import time

t1 = time.localtime()
t2 = time.strftime("%Y-%m-%d", t1)

##
def createUserName():
    
    print("Please input the user name you want to use:")
    while 1:    
        inName = input()
        inNameStart = inName[0]
        
        if type(inName) != type("Is String"):
            inName = str(inName)
        
        if inNameStart.isalpha() != True:
            print("User name must starts with letter")
        else:
            userName = inName
            print("User Name accepted: ", userName)
            break
    
    print("Please input the keyword you want to use:")
    while 1:
        inKey = input()
        inKeyStart = inKey[0]
        
        if inKeyStart.isalpha() != True:
            print("Keyword must starts with letter")
        elif inKey.find("_") == -1 and inKey.find("*") == -1 and inKey.find("#") == -1 :
            print("Keyword must include _,*, or #")
        elif len(inKey) <= 6:
            print("Keyword must be longer than 6 letters")
        else:
            keyWord = inKey
            print("Keyword accepted: ", keyWord)
            break

createUserName()

##
a = range(100/2)

c = [a[i] * 2 for i in range(len(a))]
c

##
closePrice = dict({"1/13": 7.31, "1/14": 7.28, "1/15": 7.40, "1/16": 7.43,"1/17": 7.41})
closePrice["1/20"] = 7.44

closePrice["1/20"]
closePrice["1/16"] = 7.50
