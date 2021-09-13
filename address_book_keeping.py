def main():                                     # main함수를 정의한다
   address_book ={} 				# 공백 딕셔너리를 생성한다. 
   while True :                                 # 무한히 반복한다
       user = display_menu();                   # 사용자에게 display_menu 함수를 제시한다
       if user ==1 :                            # 사용자가 1을 입력하면
          name, number = get_contact()          # get_contact함수를 제시한다
          address_book[name]= number		# name과 number를 추가한다. 
       elif user ==2 :                          # 사용자가 2를 입력하면
          name, number = get_contact()          # get_contact함수를 제시한다
          address_book.pop(name)		# name을 키로 가지고 항목을 삭제한다. 
       elif user ==3 :                          # 사용자가 3을 입력하면
          name =input("name: ")                 # 이름을 입력받는다
          if name in address_book :             # 이름이 address_book에 있으면
             print("exist")                     # exist를 출력한다
          else:                                 # 이름이 address_book에 없으면
             print("nothing")                   # nothing을 출력한다
       elif user ==4 :                          # 사용자가 4를 입력하면
          name =input("name: ")                 # 이름을 입력받는다
          if name in address_book :             # 이름이 address_book에 있으면
             new_number =input("new_number: ")  # 새로 바꿀 번호를 입력받는다
             address_book[name]= new_number     # 새로 입력받은 번호로 변경한다
          else:                                 # 이름이 address_book에 없으면
             print("nothing")                   # nothing을 출력한다
       elif user ==5 :                          # 사용자가 5를 입력하면
           for key in sorted(address_book):     # 반복문을 사용하여
              print(name,"'s phone number:", address_book[key]) #모든 연락처를 출력한다
           break                                # main 함수에서 빠져나간다
       else :                                   # 사용자가 1,2,3,4,5 외 다른 값을를 입력하면
            break                               # main 함수에서 빠져나간다
     
# 이름과 전화번호를 입력받아서 반환한다. 
def get_contact():                              # get_contact함수를 정의한다
    name =input("name: ")                       # 이름을 입력받는다
    number =input("phone number:")                  # 전화번호를 입력받는다
    return name, number			        # 튜플로 반환한다. 

# 메뉴를 화면에 출력한다. 
def display_menu() :                            # display_menu 함수를 정의한다
   print("1. Add Contact Info")                 # 1. Add Contact Info 를 출력한다
   print("2. Delete Contact Info")              # 2. Delete Contact Info를 출력한다
   print("3. Search Contact Info")              # 3. Search Contact Info를 출력한다
   print("4. Change Contact Info")              # 4. Change Contact Info를 출력한다
   print("5. Print Contact Info")               # 5. Print Contact Info를 출력한다
   print("9. Exit")                             # 9. Exit를 출력한다
   select = int(input("Choose a memu item: "))  # menu 번호를 입력받는다
   return select                                # select를 반환한

main()
